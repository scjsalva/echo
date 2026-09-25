import type { WaitingItem } from '@/types/dashboard'

export const sourceBadge: Record<WaitingItem['source'], string> = { agent: 'CC', github: 'GH', jira: 'JIRA' }

/** One line saying who is waiting and what they said. */
export function waitingSummary(item: WaitingItem): string {
  const quoted = item.detail ? `“${item.detail}”` : ''
  switch (item.kind) {
    case 'review_requested':
      return item.actor ? `${item.actor} asked you to review` : 'Your review is requested'
    case 'changes_requested':
      return `${item.actor ?? 'Someone'} requested changes${quoted ? `: ${quoted}` : ''}`
    case 'assigned':
      return item.actor ? `${item.actor} assigned it to you` : 'Assigned to you'
    case 'agent_blocked':
      return item.actor ?? ''
    default: {
      const who = item.kind === 'team_mention' ? 'mentioned your team' : 'mentioned you'
      return `${item.actor ?? 'Someone'} ${who}${quoted ? `: ${quoted}` : ''}`
    }
  }
}
