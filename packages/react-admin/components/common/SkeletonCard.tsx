import { cn } from '@/lib/utils'

interface SkeletonCardProps {
  className?: string
}

function Skeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        'animate-pulse rounded-md bg-muted',
        className
      )}
    />
  )
}

export function SkeletonCard({ className }: SkeletonCardProps) {
  return (
    <div
      data-testid="stat-skeleton"
      className={cn(
        'rounded-lg border border-border bg-card p-6 space-y-3',
        className
      )}
    >
      <Skeleton className="h-4 w-24" />
      <Skeleton className="h-8 w-16" />
      <Skeleton className="h-3 w-32" />
    </div>
  )
}
