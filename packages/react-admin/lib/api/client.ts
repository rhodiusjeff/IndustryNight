import { getAccessToken, getRefreshToken, saveSession, clearSession } from '@/lib/auth/session'

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000'

interface FetchOptions extends RequestInit {
  skipAuth?: boolean
}

class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public data?: unknown
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

let isRefreshing = false
let refreshPromise: Promise<string | null> | null = null

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = getRefreshToken()
  if (!refreshToken) return null

  try {
    const res = await fetch(`${API_BASE}/admin/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    })

    if (!res.ok) {
      clearSession()
      return null
    }

    const data = await res.json()
    saveSession(
      { accessToken: data.accessToken, refreshToken: data.refreshToken },
      data.admin
    )
    return data.accessToken as string
  } catch {
    clearSession()
    return null
  }
}

async function apiFetch<T>(path: string, options: FetchOptions = {}): Promise<T> {
  const { skipAuth = false, ...fetchOptions } = options

  const headers = new Headers(fetchOptions.headers)
  headers.set('Content-Type', headers.get('Content-Type') || 'application/json')

  if (!skipAuth) {
    const token = getAccessToken()
    if (token) {
      headers.set('Authorization', `Bearer ${token}`)
    }
  }

  const url = path.startsWith('http') ? path : `${API_BASE}${path}`
  const response = await fetch(url, { ...fetchOptions, headers })

  // Handle 401 — attempt token refresh once
  if (response.status === 401 && !skipAuth) {
    if (!isRefreshing) {
      isRefreshing = true
      refreshPromise = refreshAccessToken().finally(() => {
        isRefreshing = false
        refreshPromise = null
      })
    }

    const newToken = await refreshPromise
    if (!newToken) {
      clearSession()
      if (typeof window !== 'undefined') {
        window.location.href = '/login'
      }
      throw new ApiError('Session expired', 401)
    }

    // Retry with new token
    headers.set('Authorization', `Bearer ${newToken}`)
    const retryResponse = await fetch(url, { ...fetchOptions, headers })
    if (!retryResponse.ok) {
      const errData = await retryResponse.json().catch(() => ({}))
      throw new ApiError(
        (errData as { message?: string }).message || 'Request failed',
        retryResponse.status,
        errData
      )
    }
    return retryResponse.json() as Promise<T>
  }

  if (!response.ok) {
    const errData = await response.json().catch(() => ({}))
    throw new ApiError(
      (errData as { message?: string }).message || 'Request failed',
      response.status,
      errData
    )
  }

  // Handle 204 No Content
  if (response.status === 204) {
    return undefined as unknown as T
  }

  return response.json() as Promise<T>
}

export const apiClient = {
  get: <T>(path: string, options?: FetchOptions) =>
    apiFetch<T>(path, { ...options, method: 'GET' }),

  post: <T>(path: string, body?: unknown, options?: FetchOptions) =>
    apiFetch<T>(path, {
      ...options,
      method: 'POST',
      body: body ? JSON.stringify(body) : undefined,
    }),

  patch: <T>(path: string, body?: unknown, options?: FetchOptions) =>
    apiFetch<T>(path, {
      ...options,
      method: 'PATCH',
      body: body ? JSON.stringify(body) : undefined,
    }),

  delete: <T>(path: string, options?: FetchOptions) =>
    apiFetch<T>(path, { ...options, method: 'DELETE' }),
}

export { ApiError }
