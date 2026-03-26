'use client';

import { useEffect, useState, type ReactNode } from 'react';
import { useRouter } from 'next/navigation';
import Sidebar from '@/components/layout/Sidebar';
import Topbar from '@/components/layout/Topbar';
import EmptyState from '@/components/common/EmptyState';
import { useAuth } from '@/hooks/useAuth';

interface AppShellProps {
  children: ReactNode;
}

export default function AppShell({ children }: AppShellProps): JSX.Element {
  const router = useRouter();
  const admin = useAuth((state) => state.admin);
  const isLoading = useAuth((state) => state.isLoading);
  const isReady = useAuth((state) => state.isReady);
  const initialize = useAuth((state) => state.initialize);

  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    void initialize();
  }, [initialize]);

  useEffect(() => {
    if (isReady && !admin) {
      router.replace('/login');
    }
  }, [admin, isReady, router]);

  if (isLoading || !isReady) {
    return <EmptyState title="Loading admin session..." />;
  }

  if (!admin) {
    return <EmptyState title="Redirecting to login..." />;
  }

  return (
    <div className="flex min-h-screen bg-background">
      <Sidebar
        role={admin.role}
        collapsed={collapsed}
        mobileOpen={mobileOpen}
        onToggleCollapsed={() => setCollapsed((prev) => !prev)}
        onToggleMobile={() => setMobileOpen((prev) => !prev)}
      />
      <div className="flex min-h-screen flex-1 flex-col">
        <Topbar admin={admin} />
        <main className="flex-1 p-6">{children}</main>
      </div>
    </div>
  );
}
