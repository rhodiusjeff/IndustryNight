
export function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
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
  return String(Math.floor(1000 + Math.random() * 9000));
}
