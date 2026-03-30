'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { AppShell } from './AppShell'
import { getStoredUser, clearSession } from '@/lib/auth/session'
import { apiClient } from '@/lib/api/client'
import type { AdminUser } from '@/types/admin'

export function ClientLayout({ children }: { children: React.ReactNode }) {
  const [user] = useState<AdminUser | null>(() => getStoredUser())
  const router = useRouter()

  const handleLogout = async () => {
    try {
      await apiClient.post('/admin/auth/logout')
    } catch {
      // Ignore errors
    } finally {
      clearSession()
      router.replace('/login')
    }
  }

  // Server already validated the token — if localStorage is missing
  // (e.g. user cleared it manually), force a hard reload to /login
  if (!user) {
    if (typeof window !== 'undefined') {
      window.location.href = '/login'
    }
    return null
  }

  return (
    <AppShell user={user} onLogout={handleLogout}>
      {children}
    </AppShell>
  )
}
