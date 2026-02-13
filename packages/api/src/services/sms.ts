import Twilio from 'twilio';
import { config } from '../config/env';

let twilioClient: Twilio.Twilio | null = null;

function getClient(): Twilio.Twilio {
  if (!twilioClient) {
    if (!config.twilio.accountSid || !config.twilio.authToken) {
      throw new Error('Twilio credentials not configured');
    }
    twilioClient = Twilio(config.twilio.accountSid, config.twilio.authToken);
  }
  return twilioClient;
}

export async function sendVerificationCode(phone: string, code: string): Promise<void> {
  // In development, log instead of sending
  if (config.nodeEnv === 'development') {
    console.log(`[DEV] SMS to ${phone}: Your Industry Night verification code is ${code}`);
    return;
  }

  const client = getClient();

  await client.messages.create({
    body: `Your Industry Night verification code is ${code}. Valid for 10 minutes.`,
    from: config.twilio.phoneNumber,
    to: phone,
  });
}

export async function sendSms(phone: string, message: string): Promise<void> {
  if (config.nodeEnv === 'development') {
    console.log(`[DEV] SMS to ${phone}: ${message}`);
    return;
  }

  const client = getClient();

  await client.messages.create({
    body: message,
    from: config.twilio.phoneNumber,
    to: phone,
  });
}
