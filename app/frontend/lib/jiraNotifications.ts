import type { JiraNotification } from '@/types/dashboard'

/** What happened on a ticket, in words, e.g. "dana moved it: To Do → Done". */
export function jiraNotificationText(n: Pick<JiraNotification, 'kind' | 'actor' | 'body'>): string {
  if (n.kind === 'transition') return n.actor ? `${n.actor} moved it: ${n.body}` : `Status moved: ${n.body}`
  if (n.kind === 'assigned') return n.actor ? `${n.actor} assigned it to you` : 'Assigned to you'
  const said = n.body ? `: “${n.body}”` : ''
  if (n.kind === 'mention') return `${n.actor ?? 'Someone'} mentioned you${said}`
  return `${n.actor ?? 'Someone'} commented${said}`
}
