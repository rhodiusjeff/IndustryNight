/**
 * E2E Test Configuration
 *
 * Reads API_BASE_URL from environment. Defaults to dev if not set.
 * Run against deployed infrastructure:
 *   API_BASE_URL=https://dev-api.industrynight.net npm run test:e2e
 */

export function getBaseUrl(): string {
  const url = process.env.API_BASE_URL;
  if (!url) {
    throw new Error(
      'API_BASE_URL is required for E2E tests.\n' +
      'Example: API_BASE_URL=https://dev-api.industrynight.net npm run test:e2e'
    );
  }
  return url.replace(/\/$/, ''); // strip trailing slash
}

/**
 * Generate a unique test phone number using magic prefix.
 * Uses a random 4-digit suffix to avoid collisions across concurrent or repeated runs.
 * Format: +1555555XXXX (10 digits after country code — NANPA maximum)
 */
export function testPhone(suffix?: string): string {
  const unique = suffix ?? String(Math.floor(Math.random() * 10000)).padStart(4, '0');
  return `+1555555${unique.padStart(4, '0')}`;
}
