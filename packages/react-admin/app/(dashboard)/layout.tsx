'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { AppShell } from '@/components/layout/AppShell'
import { getStoredUser, getAccessToken, clearSession } from '@/lib/auth/session'
import { apiClient } from '@/lib/api/client'
import type { AdminUser } from '@/types/admin'

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  // Sync read on first render — avoids a flash of null while waiting for useEffect
  const [user, setUser] = useState<AdminUser | null>(() => {
    if (typeof window === 'undefined') return null
    return getStoredUser()
  })
  const [checked, setChecked] = useState(false)
  const router = useRouter()

  useEffect(() => {
    const token = getAccessToken()
    const storedUser = getStoredUser()

    if (!token || !storedUser) {
      router.replace('/login')
      return
    }

    setUser(storedUser)
    setChecked(true)
  }, [router])

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

  // If no user after hydration, we're mid-redirect — show a minimal dark screen
  if (!user || !checked) {
    return <div className="min-h-screen bg-background" />
  }

  return (
    <AppShell user={user} onLogout={handleLogout}>
      {children}
    </AppShell>
  )
}
