import { Construction } from 'lucide-react'

interface ComingSoonProps {
  screenName: string
}

export function ComingSoon({ screenName }: ComingSoonProps) {
  return (
    <div className="flex flex-col items-center justify-center h-full min-h-[400px] text-muted-foreground">
      <Construction className="h-12 w-12 mb-4 text-primary opacity-50" />
      <p className="text-lg font-medium">Coming soon — {screenName}</p>
      <p className="text-sm mt-2">This section is under construction.</p>
    </div>
  )
}
