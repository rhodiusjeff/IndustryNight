export type AdminRole = 'platformAdmin' | 'moderator' | 'eventOps'

export const NAV_PERMISSIONS: Record<string, AdminRole[]> = {
  '/':             ['platformAdmin', 'moderator', 'eventOps'],
  '/event-ops':    ['platformAdmin', 'eventOps'],
  '/users':        ['platformAdmin', 'moderator'],
  '/events':       ['platformAdmin', 'eventOps'],
  '/customers':    ['platformAdmin'],
  '/jobs':         ['platformAdmin', 'moderator'],
  '/moderation':   ['platformAdmin', 'moderator'],
  '/posh-orders':  ['platformAdmin', 'eventOps'],
  '/analytics':    ['platformAdmin'],
  '/settings':     ['platformAdmin'],
}

export function canAccess(role: AdminRole, path: string): boolean {
  const allowed = NAV_PERMISSIONS[path]
  if (!allowed) return role === 'platformAdmin' // unknown paths: platformAdmin only
  return allowed.includes(role)
}
