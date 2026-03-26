'use client'

import { useQuery } from '@tanstack/react-query'
import { apiClient } from '@/lib/api/client'
import type { DashboardStats } from '@/types/admin'

export function useDashboard() {
  return useQuery<DashboardStats>({
    queryKey: ['dashboard'],
    queryFn: () => apiClient.get<DashboardStats>('/admin/dashboard'),
    staleTime: 30 * 1000, // 30 seconds
  })
}
