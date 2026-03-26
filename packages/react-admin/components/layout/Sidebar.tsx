'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import {
  LayoutDashboard,
  Shield,
  Users,
  Calendar,
  Building2,
  Briefcase,
  Flag,
  ShoppingCart,
  BarChart3,
  Settings,
  ChevronLeft,
  ChevronRight,
  Zap,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { canAccess, type AdminRole } from '@/lib/permissions'

interface NavItem {
  label: string
  href: string
  icon: React.ComponentType<{ className?: string }>
}

const NAV_ITEMS: NavItem[] = [
  { label: 'Dashboard',    href: '/',            icon: LayoutDashboard },
  { label: 'Event Ops',    href: '/event-ops',   icon: Zap },
  { label: 'Users',        href: '/users',       icon: Users },
  { label: 'Events',       href: '/events',      icon: Calendar },
  { label: 'Customers',    href: '/customers',   icon: Building2 },
  { label: 'Jobs',         href: '/jobs',        icon: Briefcase },
  { label: 'Moderation',   href: '/moderation',  icon: Flag },
  { label: 'Posh Orders',  href: '/posh-orders', icon: ShoppingCart },
  { label: 'Analytics',    href: '/analytics',   icon: BarChart3 },
  { label: 'Settings',     href: '/settings',    icon: Settings },
]

interface SidebarProps {
  role: AdminRole
  collapsed: boolean
  onToggle: () => void
}

export function Sidebar({ role, collapsed, onToggle }: SidebarProps) {
  const pathname = usePathname()

  const visibleItems = NAV_ITEMS.filter((item) => canAccess(role, item.href))

  return (
    <aside
      className={cn(
        'flex flex-col h-full bg-card border-r border-border transition-all duration-300 ease-in-out',
        collapsed ? 'w-16' : 'w-60'
      )}
    >
      {/* Logo */}
      <div
        className={cn(
          'flex items-center h-16 px-4 border-b border-border flex-shrink-0',
          collapsed ? 'justify-center' : 'gap-3'
        )}
      >
        <div className="w-8 h-8 rounded-lg bg-primary flex items-center justify-center flex-shrink-0">
          <Shield className="h-4 w-4 text-white" />
        </div>
        {!collapsed && (
          <span className="font-semibold text-sm text-foreground truncate">
            Industry Night
          </span>
        )}
      </div>

      {/* Nav items */}
      <nav className="flex-1 overflow-y-auto py-4 px-2 space-y-1">
        {visibleItems.map((item) => {
          const Icon = item.icon
          const isActive =
            item.href === '/' ? pathname === '/' : pathname.startsWith(item.href)

          return (
            <Link
              key={item.href}
              href={item.href}
              title={collapsed ? item.label : undefined}
              className={cn(
                'flex items-center gap-3 px-3 py-2 rounded-md text-sm font-medium transition-colors',
                isActive
                  ? 'bg-primary text-white'
                  : 'text-muted-foreground hover:text-foreground hover:bg-muted',
                collapsed && 'justify-center px-2'
              )}
            >
              <Icon className="h-4 w-4 flex-shrink-0" />
              {!collapsed && <span>{item.label}</span>}
            </Link>
          )
        })}
      </nav>

      {/* Collapse toggle */}
      <div className="p-2 border-t border-border flex-shrink-0">
        <button
          onClick={onToggle}
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
          className={cn(
            'flex items-center gap-2 w-full px-3 py-2 rounded-md text-sm text-muted-foreground hover:text-foreground hover:bg-muted transition-colors',
            collapsed && 'justify-center px-2'
          )}
        >
          {collapsed ? (
            <ChevronRight className="h-4 w-4" />
          ) : (
            <>
              <ChevronLeft className="h-4 w-4" />
              <span>Collapse</span>
            </>
          )}
        </button>
      </div>
    </aside>
  )
}
