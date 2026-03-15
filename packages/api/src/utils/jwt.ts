import crypto from 'crypto';

export function generateVerificationCode(): string {
  return crypto.randomInt(100000, 1000000).toString();
}

export function generateQrData(userId: string): string {
  return `industrynight://connect/${userId}`;
}

export function parseQrData(qrData: string): string | null {
  const prefix = 'industrynight://connect/';
  if (!qrData.startsWith(prefix)) return null;
  return qrData.substring(prefix.length);
}

export function generateActivationCode(): string {
  return crypto.randomInt(1000, 10000).toString();
}
