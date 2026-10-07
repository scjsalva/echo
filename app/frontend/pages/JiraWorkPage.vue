<script setup lang="ts">
import { computed, onBeforeUnmount, ref, watch } from 'vue'
import { PhArrowClockwise, PhSparkle } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'
import { useUrlParam } from '@/composables/useUrlState'
import type { JiraWorkPageProps, WorkList, WorkTag, WorkTicket } from '@/types/dashboard'

const props = defineProps<JiraWorkPageProps>()

const dashboard = provideDashboard(props, '/api/jira/tickets')
const { data, refreshFailed } = dashboard
const { open } = provideDrawer()
const now = useNow(30_000)

const work = ref<WorkList>(props.work)
const error = ref<string | null>(null)
const refreshing = ref<string | null>(null)
const POLL_MS = 3_000

async function load() {
  work.value = await request<WorkList>('GET', '/api/jira/work').catch(() => work.value)
}

async function find(key?: string) {
  error.value = null
  refreshing.value = key ?? null
  try {
    work.value = await request<WorkList>('POST', '/api/jira/work', key ? { key } : undefined)
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Couldn't start"
    refreshing.value = null
  }
}

// Claude works in the background; check back until it's done.
let timer: ReturnType<typeof setTimeout> | undefined
watch(
  work,
  ({ running }) => {
    clearTimeout(timer)
    if (running) timer = setTimeout(load, POLL_MS)
    else refreshing.value = null
  },
  { immediate: true },
)
onBeforeUnmount(() => clearTimeout(timer))
// The board syncs every minute; who has what may have changed.
watch(data, load)

const summarised = computed(() => work.value.tickets.filter((t) => t.summary))
const WEEK_MS = 7 * 24 * 60 * 60 * 1000
const URGENT_PRIORITY = /^(highest|high|p[12])$/i
const tagged = (tag: WorkTag) => (t: WorkTicket) => t.tags.includes(tag)
// Ways to pick: Claude's tags come with its summary; the rest are from what's already known.
const LENSES: { key: string; label: string; hint: string; match: (t: WorkTicket) => boolean }[] = [
  { key: 'best', label: 'Best overall', hint: 'Summarised and ready first, then priority, due date and size.', match: () => true },
  { key: 'quick', label: 'Quick wins', hint: 'A few hours of work and ready to start.', match: (t) => t.size === 'S' && t.ready !== false },
  { key: 'urgent', label: 'Urgent', hint: 'Overdue, due within a week, or high priority.', match: (t) => URGENT_PRIORITY.test(t.priority) || Boolean(t.due && new Date(`${t.due}T23:59:59`).getTime() < now.value + WEEK_MS) },
  { key: 'bugs', label: 'Bugs', hint: 'Bug tickets.', match: (t) => /bug/i.test(t.type) },
  { key: 'clarify', label: 'Needs clarifying', hint: 'Something must be answered before anyone can start: worth asking about to unblock them.', match: (t) => t.ready === false },
  { key: 'data', label: 'Data corrections', hint: 'Fixing or backfilling records, a one-off script or migration.', match: tagged('data_correction') },
  { key: 'frontend', label: 'Frontend', hint: 'The change mostly lives in the frontend.', match: tagged('frontend') },
  { key: 'backend', label: 'Backend', hint: 'The change mostly lives in the backend.', match: tagged('backend') },
  { key: 'investigate', label: 'Investigations', hint: 'The cause must be found before anything can be fixed.', match: tagged('investigation') },
  { key: 'customer', label: 'Customer-reported', hint: 'Raised by a customer, e.g. through support.', match: tagged('customer_reported') },
]
const TAG_LABELS: Record<WorkTag, string> = { data_correction: 'Data correction', frontend: 'Frontend', backend: 'Backend', investigation: 'Investigation', customer_reported: 'Customer-reported' }

const pick = useUrlParam<string>('pick', 'best')
const lens = computed(() => LENSES.find((l) => l.key === pick.value) ?? LENSES[0])
const counts = computed(() => Object.fromEntries(LENSES.map((l) => [l.key, work.value.tickets.filter(l.match).length])))
const matching = computed(() => work.value.tickets.filter(lens.value.match))

// Already best first, so the picks are the first few, summarised or not.
const picks = computed(() => matching.value.slice(0, work.value.top))
const rest = computed(() => matching.value.slice(work.value.top))
const PAGE = 10
const shown = ref(PAGE)
watch(pick, () => (shown.value = PAGE))
const shownRest = computed(() => rest.value.slice(0, shown.value))
const unsummarised = computed(() => work.value.tickets.length - summarised.value.length)
const failure = computed(() => error.value ?? work.value.error)

const openTicket = (t: WorkTicket) => open({ type: 'ticket', key: t.key, ticket: dashboard.ticket(t.key) })

const SIZES = { S: 'A few hours', M: 'A day or two', L: 'Bigger' } as const
const formatDue = (due: string) => new Date(`${due}T00:00:00`).toLocaleDateString(undefined, { day: 'numeric', month: 'short' })
const overdue = (due: string | null) => Boolean(due && new Date(`${due}T23:59:59`).getTime() < now.value)
</script>

<template>
  <AppShell :shell="data.shell" title="Find me work" :trail="[{ label: 'Jira', href: '/jira' }]" :refresh-failed="refreshFailed" :show-first-run="false">
    <div class="grid gap-6">
      <div class="flex flex-wrap items-center gap-3">
        <BaseButton
          class="ai-border"
          :disabled="work.running"
          tooltip="Claude reads the unassigned To Do tickets and says what each is about and what you'd do. Summaries are kept for 14 days and only redone when a ticket changes, so running it again is cheap."
          @click="find()"
        >
          <PhSparkle :size="14" class="ai-icon" /> {{ work.running ? 'Finding work…' : 'Find me work' }}
        </BaseButton>
        <span class="text-[12.5px] text-muted">
          {{ work.tickets.length }} unassigned in To Do<template v-if="unsummarised && work.tickets.length">, {{ unsummarised }} not summarised yet</template>
        </span>
      </div>

      <p v-if="failure" role="alert" class="rounded-md border border-bad/40 bg-bad-soft px-3 py-2 text-[13px] text-bad">{{ failure }}</p>

      <div v-if="work.tickets.length" role="radiogroup" aria-label="Pick by" class="flex flex-wrap gap-1.5">
        <button
          v-for="l in LENSES"
          :key="l.key"
          type="button"
          role="radio"
          :aria-checked="lens.key === l.key"
          :title="l.hint"
          :class="['inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[12.5px]', lens.key === l.key ? 'border-transparent bg-accent-soft font-medium text-accent' : 'border-line bg-surface text-muted hover:text-ink']"
          @click="pick = l.key"
        >
          {{ l.label }} <span class="font-mono text-[11px] text-faint">{{ counts[l.key] }}</span>
        </button>
      </div>

      <p v-if="work.tickets.length && !matching.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">Nothing fits “{{ lens.label }}”<template v-if="unsummarised"> yet: {{ unsummarised }} tickets aren't summarised</template>.</p>

      <p v-if="!work.tickets.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">Nothing unassigned in To Do.</p>

      <section v-if="picks.length" aria-label="Top picks" class="grid gap-3">
        <h2 class="text-[11.5px] font-semibold tracking-[0.06em] text-muted uppercase">Top picks</h2>
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-3">
          <article
            v-for="t in picks"
            :key="t.key"
            class="grid cursor-pointer content-start gap-2.5 rounded-lg border border-line bg-surface px-4 py-3.5 shadow-sm hover:border-accent/40"
            @click="openTicket(t)"
          >
            <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
              <span class="font-mono text-xs font-medium text-jira">{{ t.key }}</span>
              <span class="text-[11px] text-faint">{{ t.type }}</span>
              <BaseButton
                class="ml-auto"
                size="sm"
                :disabled="work.running"
                :tooltip="t.summary ? 'Reads the ticket from Jira again. Claude only rewrites the summary if the ticket changed.' : 'Has Claude summarise just this ticket.'"
                @click.stop="find(t.key)"
              >
                <PhArrowClockwise :size="12" :class="refreshing === t.key ? 'animate-spin' : undefined" /> {{ t.summary ? 'Refresh' : 'Summarise' }}
              </BaseButton>
            </div>
            <h3 class="text-[14px] font-medium wrap-anywhere">{{ t.title }}</h3>
            <div class="flex flex-wrap gap-1.5 text-[11.5px]">
              <span class="rounded bg-subtle px-1.5 py-0.5 text-muted">{{ t.status }}</span>
              <span v-if="t.priority" class="rounded bg-subtle px-1.5 py-0.5 text-muted">{{ t.priority }}</span>
              <span v-if="t.due" :class="['rounded px-1.5 py-0.5', overdue(t.due) ? 'bg-bad-soft text-bad' : 'bg-subtle text-muted']">Due {{ formatDue(t.due) }}</span>
              <span v-if="t.size" class="rounded bg-subtle px-1.5 py-0.5 text-muted">{{ SIZES[t.size] }}</span>
              <span v-if="t.ready === false" class="rounded bg-warn-soft px-1.5 py-0.5 text-warn">Needs an answer first</span>
              <span v-for="tag in t.tags" :key="tag" class="ai-soft rounded px-1.5 py-0.5 text-muted">{{ TAG_LABELS[tag] }}</span>
            </div>
            <p v-if="!t.summary" class="text-[13px] text-faint">Not summarised yet.</p>
            <p v-if="t.summary" class="text-[13px] wrap-anywhere">{{ t.summary }}</p>
            <p v-if="t.summary" class="text-[13px] wrap-anywhere"><span class="ai-text font-medium">What you'd do:</span> {{ t.expected }}</p>
            <p v-if="t.question" class="text-[12.5px] text-muted wrap-anywhere">Open question: {{ t.question }}</p>
            <p v-if="t.summarisedAt" class="text-[11.5px] text-faint">Summarised {{ timeAgo(t.summarisedAt, now) }} ago</p>
          </article>
        </div>
      </section>

      <section v-if="rest.length" aria-label="Everything else" class="grid gap-3">
        <h2 class="text-[11.5px] font-semibold tracking-[0.06em] text-muted uppercase">{{ picks.length ? 'Everything else' : 'Up for grabs' }}</h2>
        <div class="overflow-x-auto rounded-lg border border-line bg-surface">
          <table class="w-full min-w-[44rem] text-left text-[13px]">
            <thead class="border-b border-line text-[11.5px] text-muted">
              <tr>
                <th class="px-3 py-2 font-medium">Key</th>
                <th class="px-3 py-2 font-medium">Ticket</th>
                <th class="px-3 py-2 font-medium">Status</th>
                <th class="px-3 py-2 font-medium">Priority</th>
                <th class="px-3 py-2 font-medium">Due</th>
                <th class="px-3 py-2 font-medium">Size</th>
                <th class="px-3 py-2"><span class="sr-only">Refresh</span></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="t in shownRest" :key="t.key" class="cursor-pointer border-b border-line align-top last:border-0 hover:bg-subtle" @click="openTicket(t)">
                <td class="px-3 py-2.5 font-mono text-xs font-medium whitespace-nowrap text-jira">{{ t.key }}</td>
                <td class="grid gap-1 px-3 py-2.5">
                  <span class="wrap-anywhere">{{ t.title }}</span>
                  <span v-if="t.summary" class="text-[12.5px] text-muted wrap-anywhere">{{ t.summary }} <span class="ai-text font-medium">What you'd do:</span> {{ t.expected }}</span>
                  <span v-if="t.question" class="text-[12px] text-warn wrap-anywhere">Needs an answer first: {{ t.question }}</span>
                </td>
                <td class="px-3 py-2.5 whitespace-nowrap text-muted">{{ t.status }}</td>
                <td class="px-3 py-2.5 whitespace-nowrap text-muted">{{ t.priority }}</td>
                <td :class="['px-3 py-2.5 whitespace-nowrap', overdue(t.due) ? 'text-bad' : 'text-muted']">{{ t.due ? formatDue(t.due) : '' }}</td>
                <td class="px-3 py-2.5 whitespace-nowrap text-muted">{{ t.size ? SIZES[t.size] : '' }}</td>
                <td class="px-3 py-2.5 text-right">
                  <BaseButton size="sm" :disabled="work.running" :tooltip="t.summary ? 'Reads the ticket from Jira again. Claude only rewrites the summary if the ticket changed.' : 'Has Claude summarise just this ticket.'" @click.stop="find(t.key)">
                    <PhArrowClockwise :size="12" :class="refreshing === t.key ? 'animate-spin' : undefined" /> {{ t.summary ? 'Refresh' : 'Summarise' }}
                  </BaseButton>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <BaseButton v-if="rest.length > shown" class="justify-self-center" @click="shown += PAGE">Load more ({{ rest.length - shown }} left)</BaseButton>
      </section>
    </div>
    <DrawerHost />
  </AppShell>
</template>
