import { describe, it, expect } from 'vitest'
import { canAccess } from '../lib/permissions'

describe('canAccess', () => {
  it('platformAdmin can access all routes', () => {
    expect(canAccess('platformAdmin', '/')).toBe(true)
    expect(canAccess('platformAdmin', '/settings')).toBe(true)
    expect(canAccess('platformAdmin', '/analytics')).toBe(true)
    expect(canAccess('platformAdmin', '/customers')).toBe(true)
  })

  it('eventOps can access event-ops and events but not customers or moderation', () => {
    expect(canAccess('eventOps', '/')).toBe(true)
    expect(canAccess('eventOps', '/event-ops')).toBe(true)
    expect(canAccess('eventOps', '/events')).toBe(true)
    expect(canAccess('eventOps', '/customers')).toBe(false)
    expect(canAccess('eventOps', '/moderation')).toBe(false)
    expect(canAccess('eventOps', '/analytics')).toBe(false)
    expect(canAccess('eventOps', '/settings')).toBe(false)
  })

  it('moderator can access users and moderation but not events or customers', () => {
    expect(canAccess('moderator', '/')).toBe(true)
    expect(canAccess('moderator', '/users')).toBe(true)
    expect(canAccess('moderator', '/moderation')).toBe(true)
    expect(canAccess('moderator', '/events')).toBe(false)
    expect(canAccess('moderator', '/customers')).toBe(false)
    expect(canAccess('moderator', '/settings')).toBe(false)
  })

  it('unknown path defaults to platformAdmin only', () => {
    expect(canAccess('platformAdmin', '/unknown-path')).toBe(true)
    expect(canAccess('moderator', '/unknown-path')).toBe(false)
    expect(canAccess('eventOps', '/unknown-path')).toBe(false)
  })
})
