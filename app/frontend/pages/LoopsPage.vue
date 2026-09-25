<script setup lang="ts">
import { computed, ref } from 'vue'
import AgentName from '@/components/agents/AgentName.vue'
import AppShell from '@/components/layout/AppShell.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import BasePill from '@/components/ui/BasePill.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import StatCount from '@/components/ui/StatCount.vue'
import TableCard from '@/components/ui/TableCard.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { formatTokens, timeAgo } from '@/lib/format'
import { describeLoop, eventsPerHour, loopKind } from '@/lib/loops'
import type { AgentLoop, PageData } from '@/types/dashboard'

const props = defineProps<PageData>()

const { data, refreshFailed } = provideDashboard(props, '/api/agents')
const { open } = provideDrawer()
const now = useNow(10_000)

type Filter = 'all' | AgentLoop['kind']
const filter = ref<Filter>('all')

const loops = computed(() =>
  data.value.agents
    .flatMap((agent) => agent.loops.map((loop) => ({ ...loop, agentId: agent.id, agent })))
    .sort((a, b) => (b.sessionTokensSinceStart ?? 0) - (a.sessionTokensSinceStart ?? 0)),
)
const count = (kind: Filter) => loops.value.filter((l) => kind === 'all' || l.kind === kind).length
const filters = computed(() =>
  (['all', 'monitor', 'wakeup', 'cron'] as const).map((value) => ({
    value,
    label: value === 'all' ? 'All' : loopKind[value],
    count: count(value),
  })),
)
const totalRate = computed(() => Math.round(loops.value.reduce((sum, l) => sum + eventsPerHour(l, now.value), 0)))
const visible = computed(() => loops.value.filter((l) => filter.value === 'all' || l.kind === filter.value))
</script>

<template>
  <AppShell :shell="data.shell" title="Loops" :refresh-failed="refreshFailed" :show-first-run="false">
    <div class="grid gap-5">
      <section aria-label="Loop totals" class="grid grid-cols-2 gap-5 rounded-xl border border-line bg-surface px-5 py-4 sm:max-w-3xl sm:grid-cols-5">
        <StatCount :value="count('all')" label="Loops" />
        <StatCount :value="count('monitor')" label="Monitors" />
        <StatCount :value="count('wakeup')" label="Self-paced" />
        <StatCount :value="count('cron')" label="Cron" />
        <StatCount :value="totalRate" label="Events / hour" />
      </section>

      <FilterChips v-model="filter" :options="filters" label="Filter loops" />

      <TableCard>
        <thead>
          <tr>
            <th>Loop</th><th>Session</th><th>Schedule</th><th class="text-right">Events</th><th class="text-right"><span class="inline-flex items-center gap-1">Per hour <InfoHint text="Events per hour since the loop started, measured over at least 15 minutes." /></span></th>
            <th class="text-right">
              <span class="inline-flex items-center gap-1">Session tokens <InfoHint text="Tokens the loop's session has used since the loop started, counted to the hour. Includes anything else that session did." /></span>
            </th>
            <th class="text-right">Last activity</th><th class="text-right">Started</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="!visible.length">
            <td colspan="8" class="py-8 text-center text-faint">
              No loops running. Start one in any session with <span class="font-mono">/loop</span> or a Monitor.
            </td>
          </tr>
          <tr v-for="loop in visible" :key="`${loop.agentId}-${loop.id}`" class="cursor-pointer hover:bg-subtle" @click="open({ type: 'agent', id: loop.agentId })">
            <td class="max-w-[380px]">
              <span class="font-medium break-words">{{ loop.description }}</span>
              <span class="mt-1 block"><BasePill>{{ loopKind[loop.kind] }}</BasePill></span>
            </td>
            <td class="text-[12.5px]"><AgentName :agent="loop.agent" /></td>
            <td class="text-[13px] text-muted">{{ describeLoop(loop, now) }}</td>
            <td class="text-right font-mono tabular-nums">{{ loop.events }}</td>
            <td class="text-right font-mono tabular-nums">{{ eventsPerHour(loop, now) }}</td>
            <td class="text-right font-mono tabular-nums">{{ loop.sessionTokensSinceStart != null ? formatTokens(loop.sessionTokensSinceStart) : '—' }}</td>
            <td class="text-right text-xs whitespace-nowrap text-faint">{{ loop.lastEventAt ? `${timeAgo(loop.lastEventAt, now)} ago` : '—' }}</td>
            <td class="text-right text-xs whitespace-nowrap text-faint">{{ timeAgo(loop.startedAt, now) }} ago</td>
          </tr>
        </tbody>
      </TableCard>
    </div>
    <DrawerHost />
  </AppShell>
</template>
