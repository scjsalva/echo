<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
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

const open = ref(false)
const data = ref<Pick<OverviewProps, 'githubNotifications' | 'jiraNotifications' | 'pullRequests' | 'jiraTickets'> | null>(null)
const failed = ref(false)
const root = ref<HTMLElement>()
const now = useNow()
const { openLink } = useNotificationLink()

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
  return [...github, ...jira].sort((a, b) => Date.parse(b.at) - Date.parse(a.at)).slice(0, LIMIT)
})

async function load() {
  try {
    data.value = await request('GET', '/api/notifications')
    failed.value = false
  } catch {
    failed.value = true
  }
}

// Looking at a notification marks it read, unless it's still waiting on you to act.
function choose(row: Row) {
  open.value = false
  if (row.unread && !row.needsAction) request('PATCH', `/api/notifications/${encodeURIComponent(row.id)}/read`).catch(() => null)
  openLink(row.link)
}

const onKey = (e: KeyboardEvent) => e.key === 'Escape' && (open.value = false)
const onPointer = (e: PointerEvent) => !root.value?.contains(e.target as Node) && (open.value = false)
watch(open, (isOpen) => {
  if (isOpen) {
    load()
    document.addEventListener('keydown', onKey)
    document.addEventListener('pointerdown', onPointer)
  } else {
    document.removeEventListener('keydown', onKey)
    document.removeEventListener('pointerdown', onPointer)
  }
})
onBeforeUnmount(() => (open.value = false))
</script>

<template>
  <div ref="root" class="relative">
    <button
      type="button"
      :class="linkClass"
      :aria-expanded="open"
      :aria-label="`Notifications: ${props.shell.waitingCount} waiting, ${props.shell.unreadCount} unread`"
      @click="open = !open"
    >
      <PhBell :size="15" :weight="shell.unreadCount || shell.waitingCount ? 'fill' : 'regular'" />
      <span v-if="shell.waitingCount" class="rounded-full bg-warn px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ shell.waitingCount }}</span>
      <span v-if="shell.unreadCount" class="rounded-full bg-accent px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ shell.unreadCount }}</span>
    </button>

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
              <span :class="['text-[13px] break-words', row.unread ? 'font-semibold' : 'font-medium text-muted']">{{ row.title }}</span>
              <span class="line-clamp-2 text-[12.5px] break-words text-muted">{{ row.text }}</span>
            </span>
            <span class="flex items-center gap-1.5 text-[11.5px] whitespace-nowrap text-faint">
              {{ timeAgo(row.at, now) }}
              <span v-if="row.unread" class="size-1.5 rounded-full bg-accent" aria-label="Unread" />
            </span>
          </button>
        </li>
      </ul>
      <a href="/inbox" class="border-t border-line-soft px-4 py-2.5 text-center text-[12.5px] font-medium text-accent hover:bg-subtle">See all notifications →</a>
    </div>
  </div>
</template>
