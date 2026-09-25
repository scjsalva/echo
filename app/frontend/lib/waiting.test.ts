import { describe, expect, it } from 'vitest'
import { waitingSummary } from './waiting'
import type { WaitingItem } from '@/types/dashboard'

const item = (overrides: Partial<WaitingItem>): WaitingItem => ({
  key: 'k', source: 'github', kind: 'mention', label: 'Mention', title: 'PR', actor: 'ravi', detail: null, at: '',
  clears: '', status: 'open', resolution: null, ref: {}, ...overrides,
})

describe('waitingSummary', () => {
  it('quotes what was said', () => {
    expect(waitingSummary(item({ detail: 'thoughts?' }))).toBe('ravi: “thoughts?”')
  })

  it('reads naturally when GitHub gives no comment or no person', () => {
    expect(waitingSummary(item({}))).toBe('ravi mentioned you')
    expect(waitingSummary(item({ actor: null }))).toBe('Mentioned you')
    expect(waitingSummary(item({ kind: 'review_requested', actor: null }))).toBe('Your review is requested')
  })
})
