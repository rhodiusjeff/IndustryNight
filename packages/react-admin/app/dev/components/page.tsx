import StatCard from '@/components/dashboard/StatCard';
import EmptyState from '@/components/common/EmptyState';

export default function DevComponentsPage(): JSX.Element {
  return (
    <main className="space-y-6 p-8">
      <h1 className="text-2xl font-semibold">Dev Components</h1>
      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Total Users" value={1234} />
        <StatCard label="Active Events" value={42} />
        <StatCard label="Connections Made" value={5000} />
        <StatCard label="Community Posts" value={876} />
      </div>
      <EmptyState title="Empty list example" description="Use this to validate design-system spacing and typography." />
    </main>
  );
}
