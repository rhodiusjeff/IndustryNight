import React from 'react';
import { formatNumber } from '@/lib/utils';
import SkeletonCard from '@/components/common/SkeletonCard';

interface StatCardProps {
  label: string;
  value: number;
  loading?: boolean;
}

export default function StatCard({ label, value, loading = false }: StatCardProps): JSX.Element {
  if (loading) {
    return <SkeletonCard />;
  }

  return (
    <article className="card-surface h-28 p-5">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p className="mt-3 text-3xl font-semibold tracking-tight">{formatNumber(value)}</p>
    </article>
  );
}
