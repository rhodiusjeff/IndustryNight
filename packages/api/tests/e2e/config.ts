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
 * Uses timestamp to avoid collisions across concurrent or repeated runs.
 * Format: +1555555XXXX (10 digits after country code)
 */
export function testPhone(suffix?: string): string {
  const unique = suffix ?? String(Date.now()).slice(-4);
  return `+1555555${unique.padStart(4, '0')}`;
}
