import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';
import { config } from '../config/env';

let sesClient: SESClient | null = null;

function getClient(): SESClient {
  if (!sesClient) {
    sesClient = new SESClient({
      region: config.aws.region,
      credentials: config.aws.accessKeyId && config.aws.secretAccessKey
        ? {
            accessKeyId: config.aws.accessKeyId,
            secretAccessKey: config.aws.secretAccessKey,
          }
        : undefined,
    });
  }
  return sesClient;
}

interface SendEmailParams {
  to: string;
  subject: string;
  html: string;
  text?: string;
}

export async function sendEmail({ to, subject, html, text }: SendEmailParams): Promise<void> {
  if (config.nodeEnv === 'development') {
    console.log(`[DEV] Email to ${to}: ${subject}`);
    console.log(text || html);
    return;
  }

  if (!config.aws.sesFromEmail) {
    throw new Error('SES from email not configured');
  }

  const client = getClient();

  const command = new SendEmailCommand({
    Source: config.aws.sesFromEmail,
    Destination: {
      ToAddresses: [to],
    },
    Message: {
      Subject: { Data: subject },
      Body: {
        Html: { Data: html },
        Text: text ? { Data: text } : undefined,
      },
    },
  });

  await client.send(command);
}

export async function sendWelcomeEmail(email: string, name: string): Promise<void> {
  await sendEmail({
    to: email,
    subject: 'Welcome to Industry Night!',
    html: `
      <h1>Welcome to Industry Night, ${name}!</h1>
      <p>Thank you for joining our community of creative professionals.</p>
      <p>Start networking, discover events, and unlock exclusive perks.</p>
    `,
    text: `Welcome to Industry Night, ${name}! Thank you for joining our community.`,
  });
}
