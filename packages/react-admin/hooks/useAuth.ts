'use client'

import { useState, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { apiClient } from '@/lib/api/client'
import { saveSession, clearSession, getStoredUser, getAccessToken } from '@/lib/auth/session'
import type { AdminUser, LoginCredentials, LoginResponse } from '@/types/admin'

export function useAuth() {
  const [user, setUser] = useState<AdminUser | null>(() => getStoredUser())
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const router = useRouter()

  const isAuthenticated = !!getAccessToken() && !!user

  const login = useCallback(
    async (credentials: LoginCredentials) => {
      setIsLoading(true)
      setError(null)
      try {
        const data = await apiClient.post<LoginResponse>(
          '/admin/auth/login',
          credentials,
          { skipAuth: true }
        )
        saveSession(
          { accessToken: data.accessToken, refreshToken: data.refreshToken },
          data.admin
        )
        setUser(data.admin)
        router.push('/')
      } catch (err) {
        const message =
          err instanceof Error ? err.message : 'Login failed'
        setError(message)
      } finally {
        setIsLoading(false)
      }
    },
    [router]
  )

  const logout = useCallback(async () => {
    try {
      await apiClient.post('/admin/auth/logout')
    } catch {
      // Ignore errors — clear session regardless
    } finally {
      clearSession()
      setUser(null)
      router.push('/login')
    }
  }, [router])

  return { user, isAuthenticated, isLoading, error, login, logout }
}
