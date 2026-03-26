'use client';

import { useQuery } from '@tanstack/react-query';
import { apiClient } from '@/lib/api/client';
import type { DashboardApiStats, DashboardStats } from '@/types/admin';

interface DashboardResponse {
  stats: DashboardApiStats;
}

function mapStats(stats: DashboardApiStats): DashboardStats {
  return {
    totalUsers: stats.total_users,
    activeEvents: stats.upcoming_events,
    connectionsMade: stats.total_connections,
    communityPosts: stats.total_posts,
  };
}

export function useDashboard() {
  return useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: async () => {
      const response = await apiClient<DashboardResponse>('admin/dashboard');
      return mapStats(response.stats);
    },
  });
}
