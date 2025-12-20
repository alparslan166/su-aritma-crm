import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "node:crypto";

import { config } from "../../config/env";

type PresignOptions = {
  contentType: string;
  prefix?: string;
};

export class MediaService {
  constructor(
    private readonly client = new S3Client({
      region: config.aws.region,
      // Use path-style URLs to avoid DNS issues with new buckets
      forcePathStyle: true,
    }),
  ) {}

  async createPresignedUpload({ contentType, prefix = "uploads" }: PresignOptions) {
    const objectKey = `${prefix}/${randomUUID()}`;

    const command = new PutObjectCommand({
      Bucket: config.aws.mediaBucket,
      Key: objectKey,
      ContentType: contentType,
    });

    const url = await getSignedUrl(this.client, command, { expiresIn: 300 });

    return {
      uploadUrl: url,
      key: objectKey,
      bucket: config.aws.mediaBucket,
    };
  }

  /**
   * Get a public URL for a media file key
   * Priority:
   * 1. S3_MEDIA_BASE_URL (CloudFront or public bucket URL) - most reliable
   * 2. Presigned URL (7 days validity) - stored in DB, auto-refreshed if expired
   */
  async getMediaUrl(key: string | null | undefined, longLived = false): Promise<string | null> {
    if (!key || key.trim() === "") {
      return null;
    }

    // If key is already a full URL, check if it's expired and needs refresh
    if (key.startsWith("http://") || key.startsWith("https://")) {
      // If it's a presigned URL and expired, regenerate it
      if (this.isPresignedUrlExpired(key) && longLived) {
        // Extract S3 key from URL
        const s3Key = this.extractS3KeyFromUrl(key);
        if (s3Key) {
          return this.generateLongLivedPresignedUrl(s3Key);
        }
      }
      return key;
    }

    // If key starts with "default/", it's a default photo - return as is
    if (key.startsWith("default/")) {
      return key;
    }

    // Priority 1: Check if S3_MEDIA_BASE_URL is set (CloudFront or public bucket)
    // This is the most reliable and permanent solution
    const s3BaseUrl = process.env.S3_MEDIA_BASE_URL;
    if (s3BaseUrl && s3BaseUrl.trim() !== "") {
      // Remove trailing slash from base URL if present
      const baseUrl = s3BaseUrl.endsWith("/") ? s3BaseUrl.slice(0, -1) : s3BaseUrl;
      return `${baseUrl}/${key}`;
    }

    // Priority 2: Generate long-lived presigned URL (7 days - AWS maximum)
    // This is stored in DB and will be auto-refreshed when expired
    if (longLived) {
      return this.generateLongLivedPresignedUrl(key);
    }

    // Short-lived presigned URL for temporary use (1 hour)
    try {
      const command = new GetObjectCommand({
        Bucket: config.aws.mediaBucket,
        Key: key,
      });
      const url = await getSignedUrl(this.client, command, { expiresIn: 3600 });
      return url;
    } catch (error) {
      console.error("Error generating presigned URL for media:", error);
      return null;
    }
  }

  /**
   * Generate a long-lived presigned URL (7 days - AWS maximum)
   * These URLs can be stored in database
   */
  private async generateLongLivedPresignedUrl(key: string): Promise<string | null> {
    try {
      const command = new GetObjectCommand({
        Bucket: config.aws.mediaBucket,
        Key: key,
      });
      // AWS maximum is 7 days (604800 seconds)
      const url = await getSignedUrl(this.client, command, { expiresIn: 604800 });
      return url;
    } catch (error) {
      console.error("Error generating long-lived presigned URL:", error);
      return null;
    }
  }

  /**
   * Check if a presigned URL is expired
   */
  private isPresignedUrlExpired(url: string): boolean {
    try {
      const urlObj = new URL(url);
      const expiresParam = urlObj.searchParams.get("X-Amz-Expires");
      if (!expiresParam) {
        // Not a presigned URL or already expired
        return false;
      }

      const dateParam = urlObj.searchParams.get("X-Amz-Date");
      if (!dateParam) {
        return false;
      }

      // Parse AWS date format: YYYYMMDDTHHmmssZ
      const year = parseInt(dateParam.substring(0, 4));
      const month = parseInt(dateParam.substring(4, 6)) - 1; // Month is 0-indexed
      const day = parseInt(dateParam.substring(6, 8));
      const hour = parseInt(dateParam.substring(9, 11));
      const minute = parseInt(dateParam.substring(11, 13));
      const second = parseInt(dateParam.substring(13, 15));

      const urlDate = new Date(Date.UTC(year, month, day, hour, minute, second));
      const expiresIn = parseInt(expiresParam);
      const expiryDate = new Date(urlDate.getTime() + expiresIn * 1000);

      // Consider expired if less than 1 day remaining (to refresh proactively)
      const oneDayInMs = 24 * 60 * 60 * 1000;
      return expiryDate.getTime() - Date.now() < oneDayInMs;
    } catch (error) {
      // If parsing fails, assume not expired (might be a public URL)
      return false;
    }
  }

  /**
   * Extract S3 key from a presigned URL
   */
  private extractS3KeyFromUrl(url: string): string | null {
    try {
      const urlObj = new URL(url);
      // Remove leading slash from pathname
      const path = urlObj.pathname.replace(/^\//, "");
      // Remove bucket name if present (path-style URL: /bucket/key or virtual-hosted: key)
      const pathParts = path.split("/");
      if (pathParts[0] === config.aws.mediaBucket) {
        // Path-style URL
        return pathParts.slice(1).join("/");
      }
      // Virtual-hosted style or direct key
      return path;
    } catch (error) {
      return null;
    }
  }

  /**
   * Transform photoUrl in a record to full URL
   */
  async transformPhotoUrl<T extends { photoUrl?: string | null }>(
    record: T,
  ): Promise<T & { photoUrl: string | null }> {
    const photoUrl = await this.getMediaUrl(record.photoUrl);
    return {
      ...record,
      photoUrl: photoUrl ?? null,
    };
  }

  /**
   * Transform photoUrl in an array of records to full URLs
   */
  async transformPhotoUrls<T extends { photoUrl?: string | null }>(
    records: T[],
  ): Promise<Array<T & { photoUrl: string | null }>> {
    const transformed = await Promise.all(records.map((record) => this.transformPhotoUrl(record)));
    return transformed;
  }
}

export const mediaService = new MediaService();
