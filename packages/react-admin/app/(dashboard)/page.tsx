'use client'

import { Users, Calendar, Link2, MessageSquare, RefreshCw } from 'lucide-react'
import StatCard from '@/components/dashboard/StatCard'
import { useDashboard } from '@/hooks/useDashboard'

export default function DashboardPage() {
  const { data, isLoading, isError, refetch } = useDashboard()

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-foreground">Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Platform overview
          </p>
        </div>
        {isError && (
          <button
            onClick={() => refetch()}
            className="flex items-center gap-2 px-3 py-2 text-sm text-muted-foreground hover:text-foreground hover:bg-muted rounded-md transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Retry
          </button>
        )}
      </div>

      {isError ? (
        <div className="rounded-lg border border-destructive/30 bg-destructive/10 p-6 text-center">
          <p className="text-sm text-destructive">Failed to load stats</p>
          <button
            onClick={() => refetch()}
            className="mt-3 flex items-center gap-2 mx-auto px-4 py-2 text-sm bg-destructive/20 hover:bg-destructive/30 text-foreground rounded-md transition-colors"
          >
            <RefreshCw className="h-4 w-4" />
            Retry
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            label="Total Users"
            value={data?.totalUsers ?? 0}
            icon={Users}
            loading={isLoading}
          />
          <StatCard
            label="Active Events"
            value={data?.activeEvents ?? 0}
            icon={Calendar}
            loading={isLoading}
          />
          <StatCard
            label="Connections Made"
            value={data?.totalConnections ?? 0}
            icon={Link2}
            loading={isLoading}
          />
          <StatCard
            label="Community Posts"
            value={data?.totalPosts ?? 0}
            icon={MessageSquare}
            loading={isLoading}
          />
        </div>
      )}
    </div>
  )
}
