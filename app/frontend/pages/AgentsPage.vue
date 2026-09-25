<script setup lang="ts">
import { computed, ref } from 'vue'
import AppShell from '@/components/layout/AppShell.vue'
import AgentName from '@/components/agents/AgentName.vue'
import EndedSessions from '@/components/agents/EndedSessions.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import BasePill from '@/components/ui/BasePill.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import StatusDot from '@/components/ui/StatusDot.vue'
import TableCard from '@/components/ui/TableCard.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { formatTokens, timeAgo } from '@/lib/format'
import type { Agent, PageData } from '@/types/dashboard'

const props = defineProps<PageData>()

const { data, refreshFailed } = provideDashboard(props, '/api/agents')
const { open } = provideDrawer()

useDeepLink((params) => {
  const id = params.get('agent')
  if (id && data.value.agents.some((a) => a.id === id)) open({ type: 'agent', id })
})
const now = useNow(30_000)

type Filter = 'all' | 'waiting' | 'loops' | 'background' | 'echo'
const filter = ref<Filter>('all')

const matches: Record<Filter, (a: Agent) => boolean> = {
  all: () => true,
  waiting: (a) => a.status === 'blocked',
  loops: (a) => a.loops.length > 0,
  background: (a) => a.kind === 'background',
  echo: (a) => Boolean(a.task),
}
const filters = computed(() =>
  (['all', 'waiting', 'loops', 'background', 'echo'] as const).map((value) => ({
    value,
    label: { all: 'All', waiting: 'Waiting on you', loops: 'With loops', background: 'Background', echo: 'Started by Echo' }[value],
    count: data.value.agents.filter(matches[value]).length,
  })),
)

const groups = computed(() => {
  const byGroup = new Map<string, Agent[]>()
  for (const agent of data.value.agents.filter(matches[filter.value])) {
    const group = agent.task ? 'Started by Echo' : agent.kind === 'background' ? 'Background jobs' : 'Sessions'
    byGroup.set(group, [...(byGroup.get(group) ?? []), agent])
  }
  return [...byGroup.entries()]
})

const STATUS: Record<Agent['status'], { label: string; tone: 'ok' | 'warn' | 'neutral' }> = {
  busy: { label: 'Busy', tone: 'ok' },
  running: { label: 'Running', tone: 'ok' },
  blocked: { label: 'Waiting on you', tone: 'warn' },
  idle: { label: 'Idle', tone: 'neutral' },
}
</script>

<template>
  <AppShell :shell="data.shell" title="Agents" :refresh-failed="refreshFailed" :show-first-run="false">
    <div class="grid gap-8">
      <section class="grid gap-3">
        <FilterChips v-model="filter" :options="filters" label="Filter agents" />
        <TableCard>
          <thead>
            <tr><th>Session</th><th>Status</th><th>Model</th><th>Now</th><th class="text-right">Loops</th><th class="text-right">Subagents</th><th class="text-right">Tokens today</th><th class="text-right">Context</th><th class="text-right">Active</th></tr>
          </thead>
          <tbody v-if="!groups.length">
            <tr><td colspan="9" class="py-6 text-center text-faint">No agents match this filter.</td></tr>
          </tbody>
          <tbody v-for="[group, agents] in groups" :key="group">
            <tr><td colspan="9" class="bg-canvas py-1.5! text-[11px] tracking-[0.07em] text-faint uppercase">{{ group }}</td></tr>
            <tr v-for="agent in agents" :key="agent.id" class="cursor-pointer hover:bg-subtle" @click="open({ type: 'agent', id: agent.id })">
              <td>
                <span class="flex flex-wrap items-center gap-2 text-[13px] font-medium">
                  <StatusDot :status="agent.status" /><AgentName :agent="agent" />
                  <BasePill v-if="agent.task" tone="accent">{{ agent.task.label }}</BasePill>
                </span>
                <span class="text-xs text-faint">{{ agent.task?.ref ?? agent.cwd }}<template v-if="agent.branch"> · {{ agent.branch }}</template></span>
              </td>
              <td><BasePill :tone="STATUS[agent.status].tone">{{ STATUS[agent.status].label }}</BasePill></td>
              <td class="text-[12.5px] whitespace-nowrap text-muted">{{ agent.model }}</td>
              <td class="max-w-[360px]"><span class="line-clamp-3 text-[13px] break-words">{{ agent.needs ?? agent.title ?? agent.lastReply }}</span></td>
              <td class="text-right font-mono tabular-nums">{{ agent.loops.length || '—' }}</td>
              <td class="text-right font-mono tabular-nums">{{ agent.subagents.length || '—' }}</td>
              <td class="text-right font-mono tabular-nums">{{ formatTokens(agent.tokensToday) }}</td>
              <td class="text-right font-mono tabular-nums">{{ agent.contextPercent != null ? `${agent.contextPercent}%` : '—' }}</td>
              <td class="text-right text-xs whitespace-nowrap text-faint">{{ timeAgo(agent.active, now) }}</td>
            </tr>
          </tbody>
        </TableCard>
      </section>

      <EndedSessions />
    </div>
    <DrawerHost />
  </AppShell>
</template>
