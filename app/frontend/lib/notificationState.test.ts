import { describe, expect, it } from 'vitest'
import { needsAction } from './notificationState'

describe('needsAction', () => {
  it('is true only for what still waits on you', () => {
    expect(needsAction({ reason: 'review_requested', resolution: null })).toBe(true)
    expect(needsAction({ reason: 'review_requested', resolution: 'You reviewed it' })).toBe(false)
    expect(needsAction({ reason: 'approved', resolution: null })).toBe(false)
    expect(needsAction({ kind: 'assigned', resolution: null })).toBe(true)
    expect(needsAction({ kind: 'comment', resolution: null })).toBe(false)
  })
})
