import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3630',
  },
  webServer: {
    command: `PORT=${process.env.PORT || 3630} npm run dev`,
    url: `http://localhost:${process.env.PORT || 3630}`,
    reuseExistingServer: true,
    timeout: 120 * 1000,
  },
})
