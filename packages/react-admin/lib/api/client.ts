import { clearSessionTokens, getAccessToken, getRefreshToken, setSessionTokens } from '@/lib/auth/session';

type HttpMethod = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE';

interface RequestOptions {
  method?: HttpMethod;
  body?: unknown;
  headers?: HeadersInit;
  retryOnUnauthorized?: boolean;
}

async function refreshSession(): Promise<boolean> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) {
    return false;
  }

  const response = await fetch('/api/admin/auth/refresh', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ refreshToken }),
  });

  if (!response.ok) {
    clearSessionTokens();
    return false;
  }

  const data = (await response.json()) as { accessToken: string; refreshToken: string };
  setSessionTokens(data.accessToken, data.refreshToken);
  return true;
}

export async function apiClient<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, headers, retryOnUnauthorized = true } = options;
  const token = getAccessToken();

  const requestHeaders = new Headers(headers);
  requestHeaders.set('content-type', 'application/json');
  if (token) {
    requestHeaders.set('authorization', `Bearer ${token}`);
  }

  const response = await fetch(`/api/${path.replace(/^\/+/, '')}`, {
    method,
    headers: requestHeaders,
    body: method === 'GET' ? undefined : JSON.stringify(body ?? {}),
  });

  if (response.status === 401 && retryOnUnauthorized) {
    const refreshed = await refreshSession();
    if (refreshed) {
      return apiClient<T>(path, { ...options, retryOnUnauthorized: false });
    }
    throw new Error('UNAUTHORIZED');
  }

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `HTTP ${response.status}`);
  }

  return (await response.json()) as T;
}
