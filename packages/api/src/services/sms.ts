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

export const twilioAvailable = !!(config.twilio.accountSid && config.twilio.authToken);
export const verifyAvailable = !!(twilioAvailable && config.twilio.verifyServiceSid);

export async function sendVerification(phone: string): Promise<void> {
  if (!verifyAvailable) {
    throw new Error('Twilio Verify not configured');
  }

  const client = getClient();
  await client.verify.v2
    .services(config.twilio.verifyServiceSid!)
    .verifications.create({ to: phone, channel: 'sms' });
}

export async function checkVerification(phone: string, code: string): Promise<boolean> {
  if (!verifyAvailable) {
    throw new Error('Twilio Verify not configured');
  }

  const client = getClient();
  const check = await client.verify.v2
    .services(config.twilio.verifyServiceSid!)
    .verificationChecks.create({ to: phone, code });

  return check.status === 'approved';
}

export async function sendSms(phone: string, message: string): Promise<void> {
  if (!twilioAvailable || !config.twilio.phoneNumber) {
    console.log(`[SMS-DEV] SMS to ${phone}: ${message}`);
    return;
  }

  const client = getClient();
  await client.messages.create({
    body: message,
    from: config.twilio.phoneNumber,
    to: phone,
  });
}
