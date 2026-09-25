import { inject, onScopeDispose, provide, ref, shallowRef, type InjectionKey, type ShallowRef } from 'vue'
import { request } from '@/lib/api'
import type { PageData } from '@/types/dashboard'

const REFRESH_MS = 30_000
const LIVE_CHECK_MS = 3_000

function createDashboard<T extends PageData>(initial: T, endpoint: string) {
  const data = shallowRef(initial) as ShallowRef<T>
  const refreshFailed = ref(false)
  async function refresh() {
    try {
      data.value = await request<T>('GET', endpoint)
      refreshFailed.value = false
    } catch {
      refreshFailed.value = true
    }
  }

  async function dismiss(itemKey: string) {
    await request('POST', '/api/dismissals', { item_key: itemKey })
    await refresh()
  }

  function setRead(ids: Set<string> | 'all') {
    let change = 0
    const mark = <N extends { id: string; unread: boolean }>(list?: N[]) =>
      list?.map((n) => {
        if (!n.unread || (ids !== 'all' && !ids.has(n.id))) return n
        change++
        return { ...n, unread: false }
      })
    const jiraNotifications = mark(data.value.jiraNotifications)
    const githubNotifications = mark(data.value.githubNotifications)
    data.value = { ...data.value, jiraNotifications, githubNotifications, shell: { ...data.value.shell, unreadCount: data.value.shell.unreadCount - change } }
  }

  const isUnread = (id: string) => [...(data.value.jiraNotifications ?? []), ...(data.value.githubNotifications ?? [])].some((n) => n.id === id && n.unread)

  /** Marks a notification read straight away, then tells the server (and GitHub, for GitHub ones). */
  async function markRead(id: string) {
    if (!isUnread(id)) return
    setRead(new Set([id]))
    await request('PATCH', `/api/notifications/${encodeURIComponent(id)}/read`).catch(refresh)
  }

  async function markAllRead() {
    setRead('all')
    await request('POST', '/api/notifications/read_all').catch(refresh)
  }

  const timer = setInterval(refresh, REFRESH_MS)

  // With hooks installed, a cheap check every few seconds catches changes as they happen.
  let seenVersion: number | null = null
  const liveTimer = setInterval(async () => {
    if (!data.value.shell.live) return
    const { version } = await request<{ version: number }>('GET', '/api/changes').catch(() => ({ version: seenVersion ?? 0 }))
    if (seenVersion !== null && version !== seenVersion) refresh()
    seenVersion = version
  }, LIVE_CHECK_MS)

  onScopeDispose(() => {
    clearInterval(timer)
    clearInterval(liveTimer)
  })

  return {
    data,
    refresh,
    refreshFailed,
    dismiss,
    markRead,
    markAllRead,
    agent: (id: string) => data.value.agents.find((a) => a.id === id),
    pullRequest: (key: string) => data.value.pullRequests?.find((pr) => pr.key === key),
    ticket: (key: string) => data.value.jiraTickets?.find((t) => t.key === key),
    githubNotification: (id?: string) => data.value.githubNotifications?.find((n) => n.id === id),
    jiraNotification: (id?: string) => data.value.jiraNotifications?.find((n) => n.id === id),
    waitingItem: (key: string) => data.value.waiting?.items.find((w) => w.key === key),
  }
}

export type Dashboard = ReturnType<typeof createDashboard<PageData>>
const DashboardKey: InjectionKey<Dashboard> = Symbol('dashboard')

/** Holds a page's data, refreshes it from `endpoint`, and shares lookups with drawers. */
export function provideDashboard<T extends PageData>(initial: T, endpoint = '/api/dashboard') {
  const dashboard = createDashboard(initial, endpoint)
  provide(DashboardKey, dashboard as unknown as Dashboard)
  return dashboard
}

export function useDashboard(): Dashboard {
  const dashboard = inject(DashboardKey)
  if (!dashboard) throw new Error('useDashboard() needs provideDashboard() in a parent component')
  return dashboard
}
