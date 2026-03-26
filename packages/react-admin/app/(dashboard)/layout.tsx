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
  const [user, setUser] = useState<AdminUser | null>(null)
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

  if (!checked || !user) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
      </div>
    )
  }

  return (
    <AppShell user={user} onLogout={handleLogout}>
      {children}
    </AppShell>
  )
}
