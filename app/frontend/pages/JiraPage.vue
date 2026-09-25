<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { PhFunnel, PhMagnifyingGlass } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import DoneTickets from '@/components/jira/DoneTickets.vue'
import BaseTooltip from '@/components/ui/BaseTooltip.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import JiraSearchResults from '@/components/jira/JiraSearchResults.vue'
import JiraTicketRow from '@/components/jira/JiraTicketRow.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import { JIRA_GROUP_TITLES } from '@/lib/labels'
import type { JiraCategory, JiraPageProps, JiraTicket } from '@/types/dashboard'

const props = defineProps<JiraPageProps>()

const dashboard = provideDashboard(props, '/api/jira/tickets')
const { data, refreshFailed } = dashboard
const { open } = provideDrawer()

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
const now = useNow(30_000)
// The Overview's Done stat links to /jira#done, which only exists once mounted.
onMounted(() => location.hash === '#done' && document.getElementById('done')?.scrollIntoView())

type Filter = 'assigned' | 'watching' | 'reported' | 'all'
const FILTERS: Record<Filter, { label: string; matches: (t: JiraTicket) => boolean }> = {
  assigned: { label: 'Assigned to me', matches: (t) => t.assignedToMe },
  watching: { label: 'Watching', matches: (t) => Boolean(t.watching) },
  reported: { label: 'Reported by me', matches: (t) => Boolean(t.reportedByMe) },
  all: { label: 'All', matches: () => true },
}
const OPEN_GROUPS: JiraCategory[] = ['todo', 'in_progress', 'code_review', 'post_development']

const filter = ref<Filter>('assigned')
const type = ref('all')
const showTypes = ref(false)
const query = ref('')
const searchJira = ref(false)
const searching = computed(() => query.value.trim().length > 0)
watch(query, () => (searchJira.value = false))

const tickets = computed(() => data.value.jiraTickets ?? [])
const filters = computed(() =>
  (Object.keys(FILTERS) as Filter[]).map((value) => ({ value, label: FILTERS[value].label, count: tickets.value.filter(FILTERS[value].matches).length })),
)
const inFilter = computed(() => tickets.value.filter(FILTERS[filter.value].matches))
const types = computed(() => {
  const counts = new Map<string, number>()
  for (const t of inFilter.value) counts.set(t.type, (counts.get(t.type) ?? 0) + 1)
  return [
    { value: 'all', label: 'All types', count: inFilter.value.length },
    ...[...counts.entries()].sort((a, b) => b[1] - a[1]).map(([value, count]) => ({ value, label: value, count })),
  ]
})
// A search looks through everything synced first, done tickets included; Jira
// itself is only searched when that finds nothing and you ask for it.
const groups = computed(() => {
  const q = query.value.trim().toLowerCase()
  const visible = inFilter.value.filter(
    (t) => (type.value === 'all' || t.type === type.value) && (!q || `${t.key} ${t.title}`.toLowerCase().includes(q)),
  )
  const categories: JiraCategory[] = searching.value ? [...OPEN_GROUPS, 'done'] : OPEN_GROUPS
  return categories.map((category) => ({ category, tickets: visible.filter((t) => t.category === category) })).filter((g) => g.tickets.length)
})
</script>

<template>
  <AppShell :shell="data.shell" title="Jira" :refresh-failed="refreshFailed" :show-first-run="false">
    <div v-if="!connected" class="grid max-w-xl gap-2 rounded-xl border border-dashed border-line px-6 py-10">
      <h2 class="text-base font-semibold">Jira isn't connected</h2>
      <p class="text-muted">
        Log in through the Atlassian CLI to see your tickets here.
        <a href="/settings#connections" class="font-medium text-accent hover:opacity-80">Set up Jira →</a>
      </p>
    </div>

    <div v-else class="grid gap-6">
      <div class="flex flex-wrap items-center gap-3">
        <FilterChips v-model="filter" :options="filters" label="Filter tickets" />
        <BaseTooltip :text="showTypes ? 'Hide type filter' : 'Filter by ticket type'">
          <button
            type="button"
            :aria-pressed="showTypes"
            aria-label="Filter by ticket type"
            :class="[
              'relative rounded-full border p-1.5',
              showTypes || type !== 'all' ? 'border-transparent bg-accent-soft text-accent' : 'border-line bg-surface text-muted hover:text-ink',
            ]"
            @click="showTypes = !showTypes"
          >
            <PhFunnel :size="14" :weight="type !== 'all' ? 'fill' : 'regular'" />
          </button>
        </BaseTooltip>
        <label class="relative ml-auto">
          <PhMagnifyingGlass :size="14" class="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-faint" />
          <input
            v-model="query"
            type="search"
            placeholder="Search key or title"
            aria-label="Search tickets"
            class="w-64 rounded-md border border-line bg-surface py-1.5 pr-3 pl-8 text-[13px] placeholder:text-faint"
          />
        </label>
      </div>
      <FilterChips v-if="showTypes" v-model="type" :options="types" label="Filter by ticket type" />

      <div
        v-if="searching && !groups.length && !searchJira"
        class="grid justify-items-center gap-3 rounded-[10px] border border-line bg-surface px-4 py-8 text-center"
      >
        <p class="text-[13px] text-muted">None of your synced tickets match “{{ query.trim() }}”.</p>
        <BaseButton size="sm" @click="searchJira = true"><PhMagnifyingGlass :size="13" /> Search all of Jira</BaseButton>
      </div>
      <p v-else-if="!searching && !groups.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">
        No open tickets here.
      </p>

      <section v-for="group in groups" :key="group.category">
        <SectionHeader :title="JIRA_GROUP_TITLES[group.category]" :meta="String(group.tickets.length)" />
        <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
          <JiraTicketRow v-for="ticket in group.tickets" :key="ticket.key" :ticket="ticket" :now="now" />
        </div>
      </section>

      <JiraSearchResults v-if="searchJira" :query="query.trim()" :type="type" :now="now" />
      <DoneTickets v-else-if="!searching" id="done" class="scroll-mt-4" :scope="filter" :type="type" :now="now" />

      <p v-if="syncedAt" class="text-[12.5px] text-faint">Synced from Jira {{ timeAgo(syncedAt, now) }} ago. Echo checks for changes every minute.</p>
    </div>
    <DrawerHost />
  </AppShell>
</template>
