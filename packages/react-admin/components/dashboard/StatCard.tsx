import { type LucideIcon } from 'lucide-react'
import { formatNumber } from '@/lib/utils'
import { SkeletonCard } from '@/components/common/SkeletonCard'

interface StatCardProps {
  label: string
  value: number
  icon?: LucideIcon
  loading?: boolean
  description?: string
}

export default function StatCard({
  label,
  value,
  icon: Icon,
  loading = false,
  description,
}: StatCardProps) {
  if (loading) {
    return <SkeletonCard />
  }

  return (
    <div className="rounded-lg border border-border bg-card p-6 flex flex-col gap-2 hover:border-primary/40 transition-colors">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-muted-foreground">{label}</span>
        {Icon && <Icon className="h-4 w-4 text-muted-foreground" />}
      </div>
      <p className="text-3xl font-semibold text-foreground tabular-nums">
        {formatNumber(value)}
      </p>
      {description && (
        <p className="text-xs text-muted-foreground">{description}</p>
      )}
    </div>
  )
}
