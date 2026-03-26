import { Inbox } from 'lucide-react'

interface EmptyStateProps {
  title?: string
  description?: string
  action?: React.ReactNode
}

export function EmptyState({
  title = 'No data',
  description = 'Nothing to display yet.',
  action,
}: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center h-full min-h-[300px] text-muted-foreground">
      <Inbox className="h-10 w-10 mb-4 opacity-40" />
      <p className="text-base font-medium text-foreground">{title}</p>
      <p className="text-sm mt-1">{description}</p>
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}
