import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().default('3000'),

  // Database
  DATABASE_URL: z.string().optional(),
  DB_HOST: z.string().default('localhost'),
  DB_PORT: z.string().default('5432'),
  DB_NAME: z.string().default('industrynight'),
  DB_USER: z.string().default('postgres'),
  DB_PASSWORD: z.string().optional(),

  // JWT
  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRY: z.string().default('15m'),
  JWT_REFRESH_EXPIRY: z.string().default('7d'),

  // AWS
  AWS_REGION: z.string().default('us-east-1'),
  AWS_ACCESS_KEY_ID: z.string().optional(),
  AWS_SECRET_ACCESS_KEY: z.string().optional(),
  S3_BUCKET: z.string().optional(),
  SES_FROM_EMAIL: z.string().email().optional(),

  // Twilio
  TWILIO_ACCOUNT_SID: z.string().optional(),
  TWILIO_AUTH_TOKEN: z.string().optional(),
  TWILIO_PHONE_NUMBER: z.string().optional(),
  TWILIO_VERIFY_SERVICE_SID: z.string().optional(),

  // Posh
  POSH_WEBHOOK_SECRET: z.string().optional(),

  // Audit
  AUDIT_ENABLED: z.string().default('true'),
  AUDIT_METADATA_VERSION: z.string().default('1'),
  AUDIT_ENVIRONMENT: z.enum(['development', 'production', 'test']).optional(),

  // CORS
  CORS_ORIGINS: z.string().default('http://localhost:3000,http://localhost:8080'),
});

const env = envSchema.safeParse(process.env);

if (!env.success) {
  console.error('Invalid environment variables:', env.error.format());
  process.exit(1);
}

export const config = {
  nodeEnv: env.data.NODE_ENV,
  port: parseInt(env.data.PORT, 10),

  database: {
    url: env.data.DATABASE_URL,
    host: env.data.DB_HOST,
    port: parseInt(env.data.DB_PORT, 10),
    name: env.data.DB_NAME,
    user: env.data.DB_USER,
    password: env.data.DB_PASSWORD,
  },

  jwt: {
    secret: env.data.JWT_SECRET,
    accessExpiry: env.data.JWT_ACCESS_EXPIRY,
    refreshExpiry: env.data.JWT_REFRESH_EXPIRY,
  },

  aws: {
    region: env.data.AWS_REGION,
    accessKeyId: env.data.AWS_ACCESS_KEY_ID,
    secretAccessKey: env.data.AWS_SECRET_ACCESS_KEY,
    s3Bucket: env.data.S3_BUCKET,
    sesFromEmail: env.data.SES_FROM_EMAIL,
  },

  twilio: {
    accountSid: env.data.TWILIO_ACCOUNT_SID,
    authToken: env.data.TWILIO_AUTH_TOKEN,
    phoneNumber: env.data.TWILIO_PHONE_NUMBER,
    verifyServiceSid: env.data.TWILIO_VERIFY_SERVICE_SID,
  },

  posh: {
    webhookSecret: env.data.POSH_WEBHOOK_SECRET,
  },

  audit: {
    enabled: env.data.AUDIT_ENABLED === 'true',
    metadataVersion: parseInt(env.data.AUDIT_METADATA_VERSION, 10),
    environment: env.data.AUDIT_ENVIRONMENT ?? env.data.NODE_ENV,
  },

  corsOrigins: env.data.CORS_ORIGINS.split(','),
};
