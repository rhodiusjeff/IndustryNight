import type { AdminRole } from '@/types/admin';

export const NAV_ITEMS = [
  { path: '/', label: 'Dashboard', roles: ['platformAdmin', 'moderator', 'eventOps'] },
  { path: '/event-ops', label: 'Event Ops', roles: ['platformAdmin', 'eventOps'] },
  { path: '/users', label: 'Users', roles: ['platformAdmin', 'moderator'] },
  { path: '/events', label: 'Events', roles: ['platformAdmin', 'eventOps'] },
  { path: '/customers', label: 'Customers', roles: ['platformAdmin'] },
  { path: '/jobs', label: 'Jobs', roles: ['platformAdmin', 'moderator'] },
  { path: '/moderation', label: 'Moderation', roles: ['platformAdmin', 'moderator'] },
  { path: '/posh-orders', label: 'Posh Orders', roles: ['platformAdmin', 'eventOps'] },
  { path: '/analytics', label: 'Analytics', roles: ['platformAdmin'] },
  { path: '/settings', label: 'Settings', roles: ['platformAdmin'] },
] as const;

const NAV_PERMISSIONS: Record<string, AdminRole[]> = Object.fromEntries(
  NAV_ITEMS.map((item) => [item.path, [...item.roles] as AdminRole[]]),
);

export function canAccess(role: AdminRole, path: string): boolean {
  const allowed = NAV_PERMISSIONS[path];
  if (!allowed) {
    return role === 'platformAdmin';
  }
  return allowed.includes(role);
}

export function visibleNavItems(role: AdminRole) {
  return NAV_ITEMS.filter((item) => canAccess(role, item.path));
}
