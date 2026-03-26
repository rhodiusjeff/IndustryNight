import { cookies } from 'next/headers'
import { redirect } from 'next/navigation'
import { ClientLayout } from '@/components/layout/ClientLayout'

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const cookieStore = cookies()
  const token = cookieStore.get('accessToken')?.value

  if (!token) {
    redirect('/login')
  }

  return <ClientLayout>{children}</ClientLayout>
}
