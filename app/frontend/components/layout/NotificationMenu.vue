<script setup lang="ts">
import { computed, inject, onBeforeUnmount, ref, watch } from 'vue'
import { PhBell } from '@phosphor-icons/vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import { useNotificationLink } from '@/composables/useNotificationLink'
import { useNow } from '@/composables/useNow'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'
import { githubNotificationText } from '@/lib/githubNotifications'
import { jiraNotificationText } from '@/lib/jiraNotifications'
import { needsAction } from '@/lib/notificationState'
import type { OverviewProps, ShellProps } from '@/types/dashboard'

const props = defineProps<{ shell: ShellProps; linkClass: string }>()

const LIMIT = 10
const UNREAD_LIMIT = 20

const open = ref(false)
const data = ref<Pick<OverviewProps, 'githubNotifications' | 'jiraNotifications' | 'pullRequests' | 'jiraTickets'> | null>(null)
const failed = ref(false)
const root = ref<HTMLElement>()
const now = useNow()
const { openLink } = useNotificationLink()
// Updates the counts in the header once what you've seen is marked read.
const refreshShell = inject<() => Promise<unknown>>('refreshShell', async () => undefined)

interface Row {
  id: string
  needsAction: boolean
  source: 'github' | 'jira'
  title: string
  text: string
  at: string
  unread: boolean
  link: string
}

const rows = computed<Row[]>(() => {
  if (!data.value) return []
  const { githubNotifications = [], jiraNotifications = [], pullRequests = [], jiraTickets = [] } = data.value
  const github = githubNotifications.map((n) => ({
    id: n.id, source: 'github' as const, at: n.at, unread: n.unread, needsAction: needsAction(n),
    title: pullRequests.find((pr) => pr.key === n.prKey)?.title ?? n.title ?? n.prKey,
    text: githubNotificationText(n),
    link: `/github?${new URLSearchParams({ pr: n.prKey, notification: n.id })}`,
  }))
  const jira = jiraNotifications.map((n) => ({
    id: n.id, source: 'jira' as const, at: n.at, unread: n.unread, needsAction: needsAction(n),
    title: [n.key, jiraTickets.find((t) => t.key === n.key)?.title].filter(Boolean).join(' · '),
    text: jiraNotificationText(n),
    link: `/jira?${new URLSearchParams({ ticket: n.key, notification: n.id })}`,
  }))
  // Every unread one shows, however old, so the count always matches the dots;
  // the latest read ones fill the rest.
  const all = [...github, ...jira].sort((a, b) => Date.parse(b.at) - Date.parse(a.at))
  const unread = all.filter((row) => row.unread).slice(0, UNREAD_LIMIT)
  const read = all.filter((row) => !row.unread).slice(0, Math.max(0, LIMIT - unread.length))
  return [...unread, ...read].sort((a, b) => Date.parse(b.at) - Date.parse(a.at))
})

async function load() {
  try {
    data.value = await request('GET', '/api/notifications')
    failed.value = false
  } catch {
    failed.value = true
  }
}

// Opening the bell counts as seeing what it shows, except what still waits on
// you to act. Their dots fade out once they're marked read, so you still see
// what was new first.
// The header's count drops at once; the page's own refresh, which can take a
// couple of seconds, then confirms it.
const justRead = ref(0)
const unreadCount = computed(() => Math.max(0, props.shell.unreadCount - justRead.value))
watch(() => props.shell.unreadCount, () => (justRead.value = 0))

function markSeen() {
  const ids = rows.value.filter((row) => row.unread && !row.needsAction).map((row) => row.id)
  if (!ids.length) return
  justRead.value = ids.length
  request('POST', '/api/notifications/read_some', { ids }).then(() => {
    const seen = new Set(ids)
    if (data.value) {
      data.value = {
        ...data.value,
        githubNotifications: data.value.githubNotifications?.map((n) => (seen.has(n.id) ? { ...n, unread: false } : n)),
        jiraNotifications: data.value.jiraNotifications?.map((n) => (seen.has(n.id) ? { ...n, unread: false } : n)),
      }
    }
    refreshShell()
  }, () => (justRead.value = 0))
}

// Unread ones beyond what the bell has room for.
const moreUnread = computed(() => {
  const total = [...(data.value?.githubNotifications ?? []), ...(data.value?.jiraNotifications ?? [])].filter((n) => n.unread).length
  return Math.max(0, total - UNREAD_LIMIT)
})

function choose(row: Row) {
  open.value = false
  openLink(row.link)
}

// Opens on hover, like the sync light beside it, and stays while the pointer
// moves onto the panel. The dots on what's new stay for as long as it's open;
// what it shows counts as seen when you move away. Passing over the bell (open
// under 2 seconds) marks nothing.
const CLOSE_DELAY_MS = 150
const GLANCE_MS = 2_000
let closing: ReturnType<typeof setTimeout> | undefined
let openedAt = 0
function show() {
  clearTimeout(closing)
  open.value = true
}
function hide() {
  closing = setTimeout(() => (open.value = false), CLOSE_DELAY_MS)
}
watch(open, async (isOpen) => {
  if (!isOpen) {
    if (data.value && Date.now() - openedAt >= GLANCE_MS) markSeen()
    return
  }
  openedAt = Date.now()
  await load()
})
onBeforeUnmount(() => {
  clearTimeout(closing)
})
</script>

<template>
  <div ref="root" class="relative" @mouseenter="show" @mouseleave="hide" @focusin="show" @focusout="hide" @keydown.esc="open = false">
    <a
      href="/inbox"
      :class="linkClass"
      :aria-expanded="open"
      :aria-label="`Notifications: ${props.shell.waitingCount} waiting, ${unreadCount} unread`"
    >
      <PhBell :size="15" :weight="unreadCount || shell.waitingCount ? 'fill' : 'regular'" />
      <span v-if="shell.waitingCount" class="rounded-full bg-warn px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ shell.waitingCount }}</span>
      <span v-if="unreadCount" class="rounded-full bg-accent px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ unreadCount }}</span>
    </a>

    <div
      v-if="open"
      role="dialog"
      aria-label="Latest notifications"
      class="absolute top-full right-0 z-30 mt-2 grid w-[min(420px,calc(100vw-2rem))] overflow-hidden rounded-lg border border-line bg-surface text-left shadow-xl"
    >
      <p class="border-b border-line-soft px-4 py-2.5 text-[13px] font-semibold">Latest notifications</p>
      <p v-if="failed" class="px-4 py-4 text-[13px] text-bad">Couldn't load them.</p>
      <p v-else-if="!data" class="px-4 py-4 text-[13px] text-faint">Loading…</p>
      <p v-else-if="!rows.length" class="px-4 py-4 text-[13px] text-faint">No notifications yet.</p>
      <ul v-else class="max-h-[60vh] overflow-y-auto">
        <li v-for="row in rows" :key="row.id" class="border-b border-line-soft last:border-b-0">
          <button type="button" class="grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-2.5 px-4 py-2.5 text-left hover:bg-subtle" @click="choose(row)">
            <SourceBadge :tone="row.source === 'jira' ? 'jira' : 'default'">{{ row.source === 'jira' ? 'JIRA' : 'GH' }}</SourceBadge>
            <span class="grid min-w-0 gap-0.5">
              <span :class="['text-[13px] break-words transition-colors duration-700', row.unread ? 'font-semibold' : 'font-medium text-muted']">{{ row.title }}</span>
              <span class="line-clamp-2 text-[12.5px] break-words text-muted">{{ row.text }}</span>
            </span>
            <span class="flex items-center gap-1.5 text-[11.5px] whitespace-nowrap text-faint">
              {{ timeAgo(row.at, now) }}
              <Transition leave-active-class="transition-opacity duration-700" leave-to-class="opacity-0">
                <span v-if="row.unread" class="size-1.5 rounded-full bg-accent" aria-label="Unread" />
              </Transition>
            </span>
          </button>
        </li>
      </ul>
      <p v-if="moreUnread" class="border-t border-line-soft px-4 py-2 text-center text-[12.5px] text-muted">…and {{ moreUnread }} more unread in the inbox</p>
      <a href="/inbox" class="border-t border-line-soft px-4 py-2.5 text-center text-[12.5px] font-medium text-accent hover:bg-subtle">See all notifications →</a>
    </div>
  </div>
</template>
