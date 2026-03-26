'use client';

import StatCard from '@/components/dashboard/StatCard';
import { useDashboard } from '@/hooks/useDashboard';

export default function DashboardPage(): JSX.Element {
  const { data, isLoading, isError, refetch } = useDashboard();

  if (isError) {
    return (
      <div className="flex min-h-[300px] items-center justify-center">
        <div className="text-center">
          <p className="text-lg font-medium">Failed to load stats</p>
          <button type="button" onClick={() => void refetch()} className="mt-4 rounded-md border border-border px-4 py-2 text-sm hover:bg-muted">
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <section>
      <div className="mb-6">
        <h2 className="text-2xl font-semibold">Dashboard</h2>
        <p className="text-sm text-muted-foreground">Platform snapshot for users, events, engagement, and community activity.</p>
      </div>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Total Users" value={data?.totalUsers ?? 0} loading={isLoading} />
        <StatCard label="Active Events" value={data?.activeEvents ?? 0} loading={isLoading} />
        <StatCard label="Connections Made" value={data?.connectionsMade ?? 0} loading={isLoading} />
        <StatCard label="Community Posts" value={data?.communityPosts ?? 0} loading={isLoading} />
      </div>
    </section>
  );
}
