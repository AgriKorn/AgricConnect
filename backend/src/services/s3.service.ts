import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';
import logger from '../utils/logger';

export interface PresignedUploadUrlResult {
  uploadUrl: string;
  fileKey: string;
  publicUrl: string;
}

export class S3Service {
  private client: S3Client | null = null;
  private publicBucket: string;
  private privateBucket: string;
  private region: string;

  constructor() {
    this.region = process.env.AWS_REGION || 'eu-west-1';
    this.publicBucket = process.env.AWS_S3_BUCKET_PUBLIC || 'agriconnect-public-assets';
    this.privateBucket = process.env.AWS_S3_BUCKET_PRIVATE || 'agriconnect-private-docs';

    // Instantiate S3 client if AWS credentials / IAM role are available
    if (process.env.AWS_ACCESS_KEY_ID || process.env.AWS_CONTAINER_CREDENTIALS_RELATIVE_URI) {
      this.client = new S3Client({ region: this.region });
    }
  }

  /**
   * Generates a Presigned PUT URL for uploading produce listing photos directly to public S3 bucket from Flutter app.
   */
  async generatePublicUploadUrl(fileName: string, contentType: string): Promise<PresignedUploadUrlResult> {
    const ext = fileName.split('.').pop() || 'jpg';
    const fileKey = `produce-photos/${randomUUID()}.${ext}`;

    if (!this.client) {
      logger.info(`[S3Service Stub] Generated local upload URL for ${fileKey}`);
      return {
        uploadUrl: `http://localhost:3000/api/uploads/stub?fileKey=${fileKey}`,
        fileKey,
        publicUrl: `http://localhost:3000/uploads/${fileKey}`,
      };
    }

    const command = new PutObjectCommand({
      Bucket: this.publicBucket,
      Key: fileKey,
      ContentType: contentType,
    });

    const uploadUrl = await getSignedUrl(this.client, command, { expiresIn: 900 }); // 15 mins
    const publicUrl = `https://${this.publicBucket}.s3.${this.region}.amazonaws.com/${fileKey}`;

    return { uploadUrl, fileKey, publicUrl };
  }

  /**
   * Generates a short-lived Presigned GET URL (15 mins) for viewing private driver ID or dispute documents securely.
   */
  async generatePrivateReadUrl(fileKey: string, expiresInSeconds = 900): Promise<string> {
    if (!this.client) {
      return `http://localhost:3000/api/private-docs/stub?fileKey=${fileKey}`;
    }

    const command = new GetObjectCommand({
      Bucket: this.privateBucket,
      Key: fileKey,
    });

    return await getSignedUrl(this.client, command, { expiresIn: expiresInSeconds });
  }
}

export const s3Service = new S3Service();
