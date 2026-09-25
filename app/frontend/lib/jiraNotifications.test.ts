import { describe, expect, it } from 'vitest'
import { jiraNotificationText } from './jiraNotifications'

describe('jiraNotificationText', () => {
  it('says what happened, and never shows a missing author as "null"', () => {
    expect(jiraNotificationText({ kind: 'transition', actor: 'Dana', body: 'To Do → Done' })).toBe('Dana moved it: To Do → Done')
    expect(jiraNotificationText({ kind: 'mention', actor: 'Dana', body: 'Can you look?' })).toBe('Dana mentioned you: “Can you look?”')
    expect(jiraNotificationText({ kind: 'comment', actor: null, body: 'Done' })).toBe('Someone commented: “Done”')
  })
})
