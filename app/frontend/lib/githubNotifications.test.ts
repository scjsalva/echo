import { describe, expect, it } from 'vitest'
import { githubNotificationText } from './githubNotifications'

describe('githubNotificationText', () => {
  it('says what happened', () => {
    expect(githubNotificationText({ reason: 'approved', actor: 'jhon50', body: null, mine: true })).toBe('jhon50 approved your PR')
    expect(githubNotificationText({ reason: 'reviewed', actor: 'dana', body: 'Nit on naming', mine: true })).toBe('dana reviewed your PR: “Nit on naming”')
    expect(githubNotificationText({ reason: 'merged', actor: 'dana', body: null })).toBe('dana merged it')
    expect(githubNotificationText({ reason: 'comment', actor: 'ravi', body: 'Looks good' })).toBe('ravi: “Looks good”')
  })

  it('can leave out who did it, for panels that show them separately', () => {
    expect(githubNotificationText({ reason: 'approved', actor: 'jhon50', body: null, mine: true }, { withActor: false })).toBe('approved your PR')
  })

  it("only says your PR when it's yours", () => {
    expect(githubNotificationText({ reason: 'approved', actor: 'jhon50', body: null, mine: false })).toBe('jhon50 approved the PR')
    expect(githubNotificationText({ reason: 'reviewed', actor: 'dana', body: null })).toBe('dana reviewed the PR')
  })

  it("only mentions a review request when it is one", () => {
    expect(githubNotificationText({ reason: 'author', actor: null, body: null })).toBe('New activity on this PR')
    expect(githubNotificationText({ reason: 'review_requested', actor: 'mansk89', body: null })).toBe('mansk89 asked you to review')
  })
})
