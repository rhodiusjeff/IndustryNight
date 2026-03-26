import { test, expect } from '@playwright/test';

test('unauthenticated user is redirected to login', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveURL(/\/login/);
});

test('login with invalid credentials shows error', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[name=email]', 'wrong@example.com');
  await page.fill('[name=password]', 'wrongpassword');
  await page.click('button[type=submit]');
  await expect(page.locator('[data-testid=login-error]')).toBeVisible();
});

test('login with valid credentials redirects to dashboard', async ({ page }) => {
  const email = process.env.TEST_ADMIN_EMAIL;
  const password = process.env.TEST_ADMIN_PASSWORD;

  test.skip(!email || !password, 'TEST_ADMIN_EMAIL and TEST_ADMIN_PASSWORD are required for valid credential test');

  await page.goto('/login');
  await page.fill('[name=email]', email!);
  await page.fill('[name=password]', password!);
  await page.click('button[type=submit]');
  await expect(page).toHaveURL('/');
  await expect(page.locator('h1')).toContainText('Dashboard');
});
