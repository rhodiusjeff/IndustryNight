'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { BarChart3, Briefcase, Calendar, ClipboardList, LayoutDashboard, Menu, Settings, ShieldCheck, ShoppingBag, Users, X } from 'lucide-react';
import { visibleNavItems } from '@/lib/permissions';
import { cn } from '@/lib/utils';
import type { AdminRole } from '@/types/admin';

interface SidebarProps {
  role: AdminRole;
  collapsed: boolean;
  mobileOpen: boolean;
  onToggleCollapsed: () => void;
  onToggleMobile: () => void;
}

const ICONS = {
  '/': LayoutDashboard,
  '/event-ops': ClipboardList,
  '/users': Users,
  '/events': Calendar,
  '/customers': ShoppingBag,
  '/jobs': Briefcase,
  '/moderation': ShieldCheck,
  '/posh-orders': BarChart3,
  '/analytics': BarChart3,
  '/settings': Settings,
} as const;

export default function Sidebar({ role, collapsed, mobileOpen, onToggleCollapsed, onToggleMobile }: SidebarProps): JSX.Element {
  const pathname = usePathname();
  const items = visibleNavItems(role);

  return (
    <>
      <button
        type="button"
        onClick={onToggleMobile}
        className="fixed left-4 top-4 z-40 rounded-md border border-border bg-card p-2 text-foreground md:hidden"
        aria-label="Toggle navigation"
      >
        {mobileOpen ? <X size={16} /> : <Menu size={16} />}
      </button>

      <aside
        className={cn(
          'fixed inset-y-0 left-0 z-30 border-r border-border bg-card transition-all duration-200 md:static md:z-0',
          collapsed ? 'w-20' : 'w-64',
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0',
        )}
      >
        <div className="flex h-16 items-center justify-between border-b border-border px-4">
          <div className="flex items-center gap-3">
            <div className="brand-gradient flex h-9 w-9 items-center justify-center rounded-md font-bold">IN</div>
            {!collapsed ? <span className="text-sm font-semibold">Industry Night Admin</span> : null}
          </div>
          <button type="button" onClick={onToggleCollapsed} className="hidden rounded-md p-1 text-muted-foreground hover:bg-muted md:block">
            <Menu size={16} />
          </button>
        </div>

        <nav className="space-y-1 p-3">
          {items.map((item) => {
            const Icon = ICONS[item.path as keyof typeof ICONS] ?? LayoutDashboard;
            const isActive = pathname === item.path;
            return (
              <Link
                key={item.path}
                href={item.path}
                className={cn(
                  'flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors',
                  isActive ? 'bg-primary/15 text-primary-light' : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                  collapsed ? 'justify-center' : 'justify-start',
                )}
                onClick={() => {
                  if (mobileOpen) {
                    onToggleMobile();
                  }
                }}
              >
                <Icon size={16} />
                {!collapsed ? <span>{item.label}</span> : null}
              </Link>
            );
          })}
        </nav>
      </aside>

      {mobileOpen ? <button type="button" className="fixed inset-0 z-20 bg-black/50 md:hidden" onClick={onToggleMobile} aria-label="Close navigation" /> : null}
    </>
  );
}
