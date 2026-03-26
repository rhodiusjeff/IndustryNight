'use client'

import { LogOut, ChevronDown } from 'lucide-react'
import { cn } from '@/lib/utils'
import type { AdminUser } from '@/types/admin'

const ROLE_LABELS: Record<string, string> = {
  platformAdmin: 'Platform Admin',
  moderator: 'Moderator',
  eventOps: 'Event Ops',
}

const ROLE_COLORS: Record<string, string> = {
  platformAdmin: 'bg-primary/20 text-primary-light',
  moderator: 'bg-secondary/20 text-secondary',
  eventOps: 'bg-verification/20 text-verification',
}

interface TopbarProps {
  user: AdminUser
  onLogout: () => void
}

export function Topbar({ user, onLogout }: TopbarProps) {
  return (
    <header className="h-16 flex items-center justify-between px-6 border-b border-border bg-card/50 backdrop-blur-sm flex-shrink-0">
      {/* Left: page context (empty for now — page headings go in content) */}
      <div />

      {/* Right: user info + logout */}
      <div className="flex items-center gap-3">
        <span
          className={cn(
            'text-xs font-medium px-2 py-1 rounded-full',
            ROLE_COLORS[user.role] ?? 'bg-muted text-muted-foreground'
          )}
        >
          {ROLE_LABELS[user.role] ?? user.role}
        </span>

        <div className="flex items-center gap-2 text-sm">
          <div className="w-7 h-7 rounded-full bg-primary/30 flex items-center justify-center text-xs font-semibold text-primary-light uppercase">
            {user.name.charAt(0)}
          </div>
          <span className="text-foreground font-medium hidden sm:block">
            {user.name}
          </span>
          <ChevronDown className="h-3 w-3 text-muted-foreground hidden sm:block" />
        </div>

        <button
          onClick={onLogout}
          aria-label="Logout"
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
        >
          <LogOut className="h-4 w-4" />
          <span className="hidden sm:inline">Logout</span>
        </button>
      </div>
    </header>
  )
}
