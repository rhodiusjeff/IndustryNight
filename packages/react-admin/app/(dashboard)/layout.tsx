import type { ReactNode } from 'react';
import AppShell from '@/components/layout/AppShell';

interface DashboardLayoutProps {
  children: ReactNode;
}

export default function DashboardLayout({ children }: DashboardLayoutProps): JSX.Element {
  return <AppShell>{children}</AppShell>;
}
