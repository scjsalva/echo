import { describe, expect, it } from 'vitest'
import { formatTokens, initials, padCount, timeAgo, timeUntil } from './format'

const now = Date.parse('2026-09-25T12:00:00Z')
const minutesAgo = (m: number) => new Date(now - m * 60_000).toISOString()

describe('timeAgo', () => {
  it('uses the largest sensible unit', () => {
    expect(timeAgo(new Date(now - 20_000).toISOString(), now)).toBe('20s')
    expect(timeAgo(minutesAgo(4), now)).toBe('4m')
    expect(timeAgo(minutesAgo(20 * 60), now)).toBe('20h')
    expect(timeAgo(minutesAgo(3 * 24 * 60), now)).toBe('3d')
  })

  it('never goes negative for timestamps in the future', () => {
    expect(timeAgo(minutesAgo(-5), now)).toBe('0s')
  })
})

describe('timeUntil', () => {
  it('describes future times and clamps past ones to now', () => {
    expect(timeUntil(minutesAgo(-3), now)).toBe('in 3m')
    expect(timeUntil(minutesAgo(1), now)).toBe('now')
  })
})

describe('formatTokens', () => {
  it('abbreviates thousands and millions', () => {
    expect(formatTokens(950)).toBe('950')
    expect(formatTokens(18_200)).toBe('18k')
    expect(formatTokens(4_733_500)).toBe('4.7M')
  })
})

describe('padCount', () => {
  it('pads to three digits by default', () => {
    expect(padCount(7)).toEqual(['00', '7'])
    expect(padCount(41)).toEqual(['0', '41'])
    expect(padCount(1234)).toEqual(['', '1234'])
  })
})

describe('initials', () => {
  it('handles logins and full names', () => {
    expect(initials('dnovak')).toBe('DN')
    expect(initials('Ravi Iyer')).toBe('RI')
  })
})
