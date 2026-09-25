import { ref } from 'vue'
import type { DrawerTarget } from './useDrawer'

type LinkedTarget = Extract<DrawerTarget, { type: 'agent' | 'pullRequest' | 'ticket' }>

/**
 * Where a notification's link points, as a drawer that can open over any page:
 * /agents?agent=…, /github?pr=…, /jira?ticket=…. Anything else is a page to go to.
 */
export function drawerTarget(url: string): LinkedTarget | null {
  const { pathname, searchParams } = new URL(url, location.origin)
  const notificationId = searchParams.get('notification') ?? undefined
  const agent = searchParams.get('agent')
  const pr = searchParams.get('pr')
  const ticket = searchParams.get('ticket')
  if (pathname === '/agents' && agent) return { type: 'agent', id: agent }
  if (pathname === '/github' && pr) return { type: 'pullRequest', key: pr, notificationId }
  if (pathname === '/jira' && ticket) return { type: 'ticket', key: ticket, notificationId }
  return null
}

// One per page, shared by the in-app alerts and OS notification clicks.
const linked = ref<LinkedTarget | null>(null)

/** Opens a notification's item in a drawer over the current page, or goes to its page when it isn't one. */
export function useNotificationLink() {
  function openLink(url: string) {
    const target = drawerTarget(url)
    if (target) linked.value = target
    else {
      const { pathname, search } = new URL(url, location.origin)
      location.assign(`${pathname}${search}`)
    }
  }
  return { linked, openLink, close: () => (linked.value = null) }
}
