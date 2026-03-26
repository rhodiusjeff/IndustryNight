'use client';

import { LogOut } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/hooks/useAuth';
import type { AdminUser } from '@/types/admin';

interface TopbarProps {
  admin: AdminUser;
}

export default function Topbar({ admin }: TopbarProps): JSX.Element {
  const logout = useAuth((state) => state.logout);
  const router = useRouter();

  async function handleLogout(): Promise<void> {
    await logout();
    router.replace('/login');
  }

  return (
    <header className="sticky top-0 z-10 flex h-16 items-center justify-between border-b border-border bg-card px-6">
      <div>
        <h1 className="text-xl font-semibold">Dashboard</h1>
      </div>
      <div className="flex items-center gap-4">
        <div className="text-right">
          <p className="text-sm font-medium">{admin.name}</p>
          <p className="text-xs text-muted-foreground">{admin.email}</p>
        </div>
        <span className="rounded-full border border-primary/40 bg-primary/15 px-3 py-1 text-xs font-medium text-primary-light">{admin.role}</span>
        <button type="button" onClick={handleLogout} className="inline-flex items-center gap-2 rounded-md border border-border px-3 py-2 text-sm hover:bg-muted">
          <LogOut size={14} />
          Logout
        </button>
      </div>
    </header>
  );
}
