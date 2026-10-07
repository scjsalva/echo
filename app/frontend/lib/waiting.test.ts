import { describe, expect, it } from 'vitest'
import { waitingSummary, waitingTarget } from './waiting'
import type { WaitingItem } from '@/types/dashboard'

const item = (overrides: Partial<WaitingItem>): WaitingItem => ({
  key: 'k', source: 'github', kind: 'mention', label: 'Mention', title: 'PR', actor: 'ravi', detail: null, at: '',
  clears: '', status: 'open', resolution: null, ref: {}, ...overrides,
})

describe('waitingSummary', () => {
  it('quotes what was said', () => {
    expect(waitingSummary(item({ detail: 'thoughts?' }))).toBe('ravi mentioned you: “thoughts?”')
    expect(waitingSummary(item({ kind: 'team_mention', detail: 'thoughts?' }))).toBe('ravi mentioned your team: “thoughts?”')
  })

  it('reads naturally when GitHub gives no comment or no person', () => {
    expect(waitingSummary(item({}))).toBe('ravi mentioned you')
    expect(waitingSummary(item({ actor: null }))).toBe('Someone mentioned you')
    expect(waitingSummary(item({ kind: 'changes_requested', actor: 'dana' }))).toBe('dana requested changes')
    expect(waitingSummary(item({ kind: 'changes_requested', actor: null, detail: 'Needs a test' }))).toBe('Someone requested changes: “Needs a test”')
    expect(waitingSummary(item({ kind: 'review_requested', actor: null }))).toBe('Your review is requested')
  })
})

describe('waitingTarget', () => {
  const waiting = (ref: WaitingItem['ref'], kind = 'review_requested') => item({ key: 'w1', kind, actor: 'dana', ref })
  const has = { agent: (id: string) => id === 'a1', ticket: (key: string) => key === 'APP-1' }

  it("opens the PR, ticket or agent straight away, carrying the item so its drawer can dismiss it", () => {
    expect(waitingTarget(waiting({ prKey: 'acme/app#2', notificationId: 'n1' }), has)).toEqual({ type: 'pullRequest', key: 'acme/app#2', notificationId: 'n1', waitingKey: 'w1' })
    expect(waitingTarget(waiting({ ticketKey: 'APP-1' }), has)).toEqual({ type: 'ticket', key: 'APP-1', notificationId: undefined, waitingKey: 'w1' })
    expect(waitingTarget(waiting({ agentId: 'a1' }), has)).toEqual({ type: 'agent', id: 'a1', waitingKey: 'w1' })
  })

  it("falls back to the item's own drawer for what Echo can't open", () => {
    expect(waitingTarget(waiting({ ticketKey: 'APP-99' }), has)).toEqual({ type: 'waiting', key: 'w1' })
    expect(waitingTarget(waiting({ agentId: 'gone' }), has)).toEqual({ type: 'waiting', key: 'w1' })
  })

  it('says a re-request is asking you to review again', () => {
    expect(waitingSummary(waiting({}, 're_review_requested'))).toBe('dana asked you to review again')
  })
})
