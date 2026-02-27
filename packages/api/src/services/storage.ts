import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { config } from '../config/env';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';

let s3Client: S3Client | null = null;

function getClient(): S3Client {
  if (!s3Client) {
    s3Client = new S3Client({
      region: config.aws.region,
      credentials: config.aws.accessKeyId && config.aws.secretAccessKey
        ? { accessKeyId: config.aws.accessKeyId, secretAccessKey: config.aws.secretAccessKey }
        : undefined,
    });
  }
  return s3Client;
}

export const s3Available = !!config.aws.s3Bucket;

const CONTENT_TYPES: Record<string, string> = {
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
};

export async function uploadImage(
  buffer: Buffer,
  originalName: string,
  folder: string
): Promise<string> {
  const ext = path.extname(originalName).toLowerCase() || '.jpg';
  const key = `${folder}/${uuidv4()}${ext}`;

  if (!s3Available) {
    console.log(`[DEV] S3 upload skipped: ${key} (${buffer.length} bytes)`);
    return `https://placeholder.s3.amazonaws.com/${key}`;
  }

  const client = getClient();
  await client.send(new PutObjectCommand({
    Bucket: config.aws.s3Bucket!,
    Key: key,
    Body: buffer,
    ContentType: CONTENT_TYPES[ext] || 'image/jpeg',
    ACL: 'public-read',
  }));

  return `https://${config.aws.s3Bucket}.s3.${config.aws.region}.amazonaws.com/${key}`;
}

export async function deleteImage(url: string): Promise<void> {
  if (!s3Available) {
    console.log(`[DEV] S3 delete skipped: ${url}`);
    return;
  }

  const urlParts = url.split('.amazonaws.com/');
  if (urlParts.length < 2) return;
  const key = urlParts[1];

  const client = getClient();
  await client.send(new DeleteObjectCommand({
    Bucket: config.aws.s3Bucket!,
    Key: key,
  }));
}
