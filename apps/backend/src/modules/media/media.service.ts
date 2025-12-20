import { GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "node:crypto";

import { config } from "@/config/env";

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
   * If S3_MEDIA_BASE_URL is set, use it. Otherwise, generate a presigned URL.
   */
  async getMediaUrl(key: string | null | undefined): Promise<string | null> {
    if (!key || key.trim() === "") {
      return null;
    }

    // If key is already a full URL, return it
    if (key.startsWith("http://") || key.startsWith("https://")) {
      return key;
    }

    // If key starts with "default/", it's a default photo - return as is
    if (key.startsWith("default/")) {
      return key;
    }

    // Check if S3_MEDIA_BASE_URL is set (for public buckets or CDN)
    const s3BaseUrl = process.env.S3_MEDIA_BASE_URL;
    if (s3BaseUrl && s3BaseUrl.trim() !== "") {
      // Remove trailing slash from base URL if present
      const baseUrl = s3BaseUrl.endsWith("/") ? s3BaseUrl.slice(0, -1) : s3BaseUrl;
      return `${baseUrl}/${key}`;
    }

    // Fallback: Generate a presigned URL (expires in 1 hour)
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
