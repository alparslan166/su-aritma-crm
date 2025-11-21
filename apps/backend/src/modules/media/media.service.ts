import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "node:crypto";

import { config } from "@/config/env";

type PresignOptions = {
  contentType: string;
  prefix?: string;
};

export class MediaService {
  constructor(private readonly client = new S3Client({ region: config.aws.region })) {}

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
}

export const mediaService = new MediaService();

