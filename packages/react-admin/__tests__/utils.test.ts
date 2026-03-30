import { describe, it, expect } from 'vitest'
import { formatNumber, cn } from '../lib/utils'

describe('formatNumber', () => {
  it('formats 0', () => expect(formatNumber(0)).toBe('0'))
  it('formats 1234 as 1,234', () => expect(formatNumber(1234)).toBe('1,234'))
  it('formats 1000000 as 1,000,000', () => expect(formatNumber(1000000)).toBe('1,000,000'))
})

describe('cn', () => {
  it('merges class names', () => {
    expect(cn('a', 'b')).toBe('a b')
  })

  it('handles conditional classes', () => {
    expect(cn('a', false && 'b', 'c')).toBe('a c')
  })

  it('merges tailwind conflicts correctly', () => {
    expect(cn('px-2', 'px-4')).toBe('px-4')
  })
})
