/**
 * E2E API Client
 *
 * Typed fetch wrapper for testing against deployed API endpoints.
 * Handles auth headers, JSON parsing, and error extraction.
 */

import { getBaseUrl } from './config';

export type ApiResponse<T = unknown> = {
  status: number;
  body: T;
  headers: Record<string, string>;
};

export type AuthTokens = {
  accessToken: string;
  refreshToken: string;
  user: Record<string, unknown>;
  isNewUser?: boolean;
};

async function request<T>(
  method: string,
  path: string,
  options: {
    body?: unknown;
    accessToken?: string;
    refreshToken?: string;
  } = {}
): Promise<ApiResponse<T>> {
  const url = `${getBaseUrl()}${path}`;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };

  if (options.accessToken) {
    headers['Authorization'] = `Bearer ${options.accessToken}`;
  }

  const res = await fetch(url, {
    method,
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  let body: T;
  const contentType = res.headers.get('content-type') ?? '';
  if (contentType.includes('application/json')) {
    body = await res.json() as T;
  } else {
    body = await res.text() as unknown as T;
  }

  const headers2: Record<string, string> = {};
  res.headers.forEach((v, k) => { headers2[k] = v; });

  return { status: res.status, body, headers: headers2 };
}

export const api = {
  get: <T>(path: string, accessToken?: string) =>
    request<T>('GET', path, { accessToken }),

  post: <T>(path: string, body: unknown, accessToken?: string) =>
    request<T>('POST', path, { body, accessToken }),

  patch: <T>(path: string, body: unknown, accessToken?: string) =>
    request<T>('PATCH', path, { body, accessToken }),

  delete: <T>(path: string, accessToken?: string) =>
    request<T>('DELETE', path, { accessToken }),
};

/**
 * Full auth flow: request-code → verify-code → return tokens.
 * Uses magic test phone prefix so no real SMS is sent.
 */
export async function authenticateTestPhone(phone: string): Promise<AuthTokens> {
  const codeRes = await api.post<{ message: string; devCode?: string }>(
    '/auth/request-code',
    { phone }
  );

  if (codeRes.status !== 200) {
    throw new Error(`request-code failed: ${codeRes.status} ${JSON.stringify(codeRes.body)}`);
  }

  if (!codeRes.body.devCode) {
    throw new Error(
      'No devCode in response. Magic prefix may be blocked in this environment, ' +
      'or NODE_ENV=production is set.'
    );
  }

  const verifyRes = await api.post<AuthTokens>('/auth/verify-code', {
    phone,
    code: codeRes.body.devCode,
  });

  if (verifyRes.status !== 200) {
    throw new Error(`verify-code failed: ${verifyRes.status} ${JSON.stringify(verifyRes.body)}`);
  }

  return verifyRes.body;
}
