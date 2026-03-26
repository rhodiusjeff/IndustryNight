import { defineConfig } from '@playwright/test';

const port = process.env.PORT || '3630';

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || `http://localhost:${port}`,
  },
  webServer: {
    command: `PORT=${port} npm run dev`,
    url: `http://localhost:${port}`,
    reuseExistingServer: true,
  },
});
