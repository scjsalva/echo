<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { PhMagnifyingGlass, PhSparkle, PhUser } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import FilterMenu, { type FilterGroup } from '@/components/ui/FilterMenu.vue'
import BoardTicketCard from '@/components/jira/BoardTicketCard.vue'
import JiraSearchResults from '@/components/jira/JiraSearchResults.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { useUrlList, useUrlParam } from '@/composables/useUrlState'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import type { JiraBoard, JiraPageProps, JiraTicket } from '@/types/dashboard'

const props = defineProps<JiraPageProps>()

const dashboard = provideDashboard(props, '/api/jira/tickets')
const { data, refreshFailed } = dashboard
const { open } = provideDrawer()
const now = useNow(30_000)

// Echo follows one board.
const board = computed<JiraBoard | undefined>(() => data.value.jiraBoards?.boards[0])
const boardId = computed(() => String(board.value?.id ?? ''))

// These read as words in the address bar, e.g. ?assignee=me,unassigned.
const UNASSIGNED = 'unassigned'
// You, in the Assignee filter: the same choice as Assigned to me, so each shows the other.
const ME = 'me'
const NO_SPRINT = 'none'
// A scrum board opens on its running sprint, like it does in Jira.
const activeSprints = () => (board.value?.sprints ?? []).filter((s) => s.state === 'active').map((s) => s.name)

// The filters live in the address bar (?status=…&assignee=me), like the rest of Echo's pages,
// so a reload, a bookmark or a link from the Overview shows the same board.
const lists = { status: useUrlList('status'), type: useUrlList('type'), assignee: useUrlList('assignee'), sprint: useUrlList('sprint', activeSprints()) }
const filters = computed<Record<string, string[]>>({
  get: () => ({ status: lists.status.value, type: lists.type.value, assignee: lists.assignee.value, sprint: lists.sprint.value }),
  set: (value) => (Object.keys(lists) as (keyof typeof lists)[]).forEach((key) => (lists[key].value = value[key] ?? [])),
})
const mine = computed({
  get: () => filters.value.assignee.includes(ME),
  set: (on) => (lists.assignee.value = on ? [...lists.assignee.value, ME] : lists.assignee.value.filter((a) => a !== ME)),
})
const assigneeOf = (t: JiraTicket) => (t.assignedToMe ? ME : t.assignee || UNASSIGNED)
const query = useUrlParam('q', '')
const searchJira = ref(false)
watch(query, () => (searchJira.value = false))

// ?ticket=KEY from a notification opens it. (Filters, e.g. the Overview's ?assignee=me, are read above.)
useDeepLink((params) => {
  const key = params.get('ticket')
  const notificationId = params.get('notification') ?? undefined
  if (!key) return
  if (notificationId) dashboard.markRead(notificationId)
  if (dashboard.ticket(key)) open({ type: 'ticket', key, notificationId })
  else {
    // Not synced any more; the notification still knows where the ticket lives.
    const url = dashboard.jiraNotification(notificationId)?.url
    if (url) window.open(url, '_blank', 'noopener')
  }
})

const tickets = computed(() =>
  board.value ? (data.value.jiraTickets ?? []).filter((t) => t.boards?.[boardId.value] !== undefined).sort((a, b) => a.boards![boardId.value] - b.boards![boardId.value]) : [],
)
const shownStatuses = computed(() => {
  const listed = (board.value?.statuses ?? []).filter((s) => !s.hidden).map((s) => s.name)
  // A status the board hasn't been told about yet still shows, after the rest.
  const unseen = [...new Set(tickets.value.map((t) => t.status))].filter((s) => !board.value?.statuses.some((b) => b.name === s))
  return [...listed, ...unseen]
})

const tally = (key: (t: JiraTicket) => string) => {
  const counts = new Map<string, number>()
  for (const t of tickets.value) counts.set(key(t), (counts.get(key(t)) ?? 0) + 1)
  return counts
}
const groups = computed<FilterGroup[]>(() => {
  const statuses = tally((t) => t.status)
  const types = tally((t) => t.type)
  const assignees = tally(assigneeOf)
  const myName = tickets.value.find((t) => t.assignedToMe)?.assignee || 'Me'
  const sprints = tally((t) => t.sprint || NO_SPRINT)
  const byCount = (counts: Map<string, number>) => [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
  return [
    { key: 'status', label: 'Status', options: shownStatuses.value.map((name) => ({ value: name, label: name, count: statuses.get(name) ?? 0 })) },
    { key: 'type', label: 'Ticket type', options: byCount(types).map(([value, count]) => ({ value, label: value, count })) },
    { key: 'assignee', label: 'Assignee', options: byCount(assignees).map(([value, count]) => ({ value, label: value === UNASSIGNED ? 'Unassigned' : value === ME ? myName : value, count })) },
    // Only scrum boards have sprints: the running one first, then what's next, then tickets in none.
    ...(board.value?.sprints.length
      ? [{ key: 'sprint', label: 'Sprint', options: [
          ...board.value.sprints.map((s) => ({ value: s.name, label: s.state === 'active' ? `${s.name} (active)` : s.name, count: sprints.get(s.name) ?? 0 })),
          { value: NO_SPRINT, label: 'No sprint', count: sprints.get(NO_SPRINT) ?? 0 },
        ] }]
      : []),
  ]
})

const passes = (t: JiraTicket) => {
  const f = filters.value
  const q = query.value.trim().toLowerCase()
  return (
    (!f.status.length || f.status.includes(t.status)) &&
    (!f.type.length || f.type.includes(t.type)) &&
    (!f.assignee.length || f.assignee.includes(assigneeOf(t))) &&
    (!f.sprint.length || f.sprint.includes(t.sprint || NO_SPRINT)) &&
    (!q || `${t.key} ${t.title}`.toLowerCase().includes(q))
  )
}
// Every to-do status shares one To Do column, which also takes your own Backlog
// tickets; the rest get a column each, in the board's order. Hidden statuses only
// show when you filter to them.
const TODO = 'To Do'
const BACKLOG = /^backlog$/i
const statusOf = (name: string) => board.value?.statuses.find((s) => s.name === name)
const columnOf = (t: JiraTicket) => (t.category === 'todo' ? TODO : t.status)
const onBoard = (t: JiraTicket) => {
  const status = statusOf(t.status)
  return !status?.hidden || (BACKLOG.test(t.status) && t.assignedToMe) || filters.value.status.includes(t.status)
}
const sections = computed(() => {
  const visible = tickets.value.filter((t) => onBoard(t) && passes(t))
  const names = [...shownStatuses.value, ...filters.value.status.filter((s) => !shownStatuses.value.includes(s))]
  const columns = [...new Set(names.map((name) => (statusOf(name)?.group ?? tickets.value.find((t) => t.status === name)?.category) === 'todo' ? TODO : name))]
  if (!columns.includes(TODO) && visible.some((t) => columnOf(t) === TODO)) columns.unshift(TODO)
  return columns.map((name) => ({ name, tickets: visible.filter((t) => columnOf(t) === name) }))
})
const searching = computed(() => query.value.trim().length > 0)
const matching = computed(() => sections.value.some((s) => s.tickets.length))

// In a column, a child sits right under its parent when both are there, nested
// one step per level; everything else keeps the board's order.
const nested = (column: JiraTicket[]) => {
  const here = new Set(column.map((t) => t.key))
  const childrenOf = (key: string) => column.filter((t) => t.parent?.key === key)
  const out: { ticket: JiraTicket; depth: number }[] = []
  const place = (t: JiraTicket, depth: number) => {
    out.push({ ticket: t, depth })
    childrenOf(t.key).forEach((c) => place(c, depth + 1))
  }
  column.filter((t) => !t.parent || !here.has(t.parent.key)).forEach((t) => place(t, 0))
  return out
}

// The board fills the screen below it and scrolls itself, both ways, like Jira's.
const boardEl = ref<HTMLElement>()
const boardHeight = ref<number | null>(null)
// What sits below it (the sync line, the page's padding) stays on screen too.
function fit() {
  const rect = boardEl.value?.getBoundingClientRect()
  if (!rect) return
  const below = document.documentElement.scrollHeight - (rect.bottom + window.scrollY)
  boardHeight.value = Math.max(240, window.innerHeight - (rect.top + window.scrollY) - below)
}
onMounted(() => {
  nextTick(fit)
  window.addEventListener('resize', fit)
})
onBeforeUnmount(() => window.removeEventListener('resize', fit))
watch(() => sections.value.length > 0, () => nextTick(fit))

</script>

<template>
  <AppShell :shell="data.shell" title="Jira" :refresh-failed="refreshFailed" :show-first-run="false" :fill="Boolean(board)">
    <div v-if="!connected" class="grid max-w-xl gap-2 rounded-xl border border-dashed border-line px-6 py-10">
      <h2 class="text-base font-semibold">Jira isn't connected</h2>
      <p class="text-muted">
        Log in through the Atlassian CLI to see your tickets here.
        <a href="/settings#connections" class="font-medium text-accent hover:opacity-80">Set up Jira →</a>
      </p>
    </div>

    <div v-else class="grid gap-5">
      <div v-if="!board" class="grid max-w-xl gap-2 rounded-xl border border-dashed border-line px-6 py-8">
        <h2 class="text-base font-semibold">Choose your board</h2>
        <p class="text-muted">
          Your board's tickets show here, in a column per status.
          <a href="/settings#jira" class="font-medium text-accent hover:opacity-80">Choose your board in Settings →</a>
        </p>
      </div>

      <template v-else>
        <div class="relative flex flex-wrap items-center gap-2">
          <button
            type="button"
            :aria-pressed="mine"
            :class="['inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[12.5px]', mine ? 'border-transparent bg-accent-soft font-medium text-accent' : 'border-line bg-surface text-muted hover:text-ink']"
            @click="mine = !mine"
          >
            <PhUser :size="13" :weight="mine ? 'fill' : 'regular'" /> Assigned to me
          </button>
          <FilterMenu v-model="filters" :groups="groups" />
          <BaseButton href="/jira/work" size="sm" class="ai-border" tooltip="The unassigned To Do tickets, with what each is about and what you'd do."><PhSparkle :size="13" class="ai-icon" /> Find me work</BaseButton>
          <span v-if="syncedAt" class="ml-auto text-[12px] text-faint" title="Echo checks Jira for changes every minute">Synced {{ timeAgo(syncedAt, now) }} ago</span>
          <label class="relative">
            <PhMagnifyingGlass :size="14" class="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-faint" />
            <input
              v-model="query"
              type="search"
              placeholder="Search key or title"
              aria-label="Search tickets"
              class="w-64 max-w-full rounded-md border border-line bg-surface py-1.5 pr-3 pl-8 text-[13px] placeholder:text-faint"
            />
          </label>
        </div>

        <div v-if="searching && !matching && !searchJira" class="grid justify-items-center gap-3 rounded-[10px] border border-line bg-surface px-4 py-8 text-center">
          <p class="text-[13px] text-muted">Nothing on {{ board?.name }} matches “{{ query.trim() }}”.</p>
          <BaseButton size="sm" @click="searchJira = true"><PhMagnifyingGlass :size="13" /> Search all of Jira</BaseButton>
        </div>
        <p v-else-if="!tickets.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">No tickets here.</p>

        <!-- Jira's board: a column per status, side by side, scrolling sideways when they don't all fit. -->
        <div
          v-if="sections.length"
          ref="boardEl"
          class="-mx-4 overflow-auto px-4 sm:-mx-7 sm:px-7"
          :style="boardHeight ? { maxHeight: `${boardHeight}px` } : undefined"
        >
          <!-- Columns stretch to the longest, so a short one's name stays pinned too. -->
          <div class="flex items-stretch gap-3">
            <section v-for="section in sections" :key="section.name" :aria-label="section.name" class="flex w-[13.6rem] shrink-0 flex-col rounded-lg bg-subtle">
              <!-- Each column's name stays in view as the board scrolls. -->
              <h3 class="sticky top-0 z-10 flex items-center gap-2 rounded-t-lg bg-subtle px-3 pt-2.5 pb-2">
                <span class="text-[11.5px] font-semibold tracking-[0.06em] text-muted uppercase">{{ section.name }}</span>
                <span class="font-mono text-[11px] text-faint">{{ section.tickets.length }}</span>
              </h3>
              <div class="grid gap-2 px-2 pb-2">
                <!-- A subtask has a line down its left, whether or not its parent is in this column. -->
                <div
                  v-for="{ ticket, depth } in nested(section.tickets)"
                  :key="ticket.key"
                  :class="ticket.subtask ? 'border-l-2 border-accent/40 pl-1.5' : undefined"
                  :style="ticket.subtask ? 'margin-left: 0.25rem;' : undefined"
                  :data-depth="depth"
                  :data-subtask="ticket.subtask ? '' : undefined"
                >
                  <BoardTicketCard :ticket="ticket" />
                </div>
                <p v-if="!section.tickets.length" class="px-1 pb-1 text-[12.5px] text-faint">No tickets</p>
              </div>
            </section>
          </div>
        </div>
      </template>

      <JiraSearchResults v-if="searchJira" :query="query.trim()" type="all" :now="now" />

      <p v-if="syncedAt && !board" class="text-[12.5px] text-faint">Synced from Jira {{ timeAgo(syncedAt, now) }} ago. Echo checks for changes every minute.</p>
    </div>
    <DrawerHost />
  </AppShell>
</template>
