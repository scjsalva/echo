import type { GithubNotification, JiraNotification } from '@/types/dashboard'

const GITHUB_WAITING = ['review_requested', 'mention', 'team_mention', 'changes_requested']
const JIRA_WAITING = ['mention', 'assigned']

/**
 * Whether a notification is still waiting on you to do something (review,
 * reply, push, move the ticket). Those stay unread until you've done it,
 * rather than being marked read just for being looked at.
 */
export function needsAction(n: Pick<GithubNotification, 'reason' | 'resolution'> | Pick<JiraNotification, 'kind' | 'resolution'>): boolean {
  if (n.resolution) return false
  return 'reason' in n ? GITHUB_WAITING.includes(n.reason) : JIRA_WAITING.includes(n.kind)
}
