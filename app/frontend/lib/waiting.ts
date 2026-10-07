import type { DrawerTarget } from '@/composables/useDrawer'
import type { WaitingItem } from '@/types/dashboard'

export const sourceBadge: Record<WaitingItem['source'], string> = { agent: 'CC', github: 'GH', jira: 'JIRA' }

/** One line saying who is waiting and what they said. */
export function waitingSummary(item: WaitingItem): string {
  const quoted = item.detail ? `“${item.detail}”` : ''
  switch (item.kind) {
    case 'review_requested':
      return item.actor ? `${item.actor} asked you to review` : 'Your review is requested'
    case 're_review_requested':
      return item.actor ? `${item.actor} asked you to review again` : 'Your review is requested again'
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

/**
 * Where clicking a waiting item goes: straight to its agent, PR or ticket, carrying
 * the item so that drawer can dismiss it. Only what Echo can't open (e.g. a ticket
 * it doesn't sync) falls back to the item's own drawer.
 */
export function waitingTarget(item: WaitingItem, has: { agent: (id: string) => unknown; ticket: (key: string) => unknown }): DrawerTarget {
  const { agentId, prKey, ticketKey, notificationId } = item.ref
  if (agentId && has.agent(agentId)) return { type: 'agent', id: agentId, waitingKey: item.key }
  if (prKey) return { type: 'pullRequest', key: prKey, notificationId, waitingKey: item.key }
  if (ticketKey && has.ticket(ticketKey)) return { type: 'ticket', key: ticketKey, notificationId, waitingKey: item.key }
  return { type: 'waiting', key: item.key }
}
