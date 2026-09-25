<script setup lang="ts">
import { computed } from 'vue'
import CollapsibleSection from '@/components/ui/CollapsibleSection.vue'
import AgentName from '@/components/agents/AgentName.vue'
import StatusDot from '@/components/ui/StatusDot.vue'
import MiniRow from './MiniRow.vue'
import SideEmpty from './SideEmpty.vue'
import SideGroupLabel from './SideGroupLabel.vue'
import { useDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { usePersistentFlag } from '@/composables/usePersistentFlag'
import { timeUntil } from '@/lib/format'
import type { Agent } from '@/types/dashboard'

const props = defineProps<{ agents: Agent[] }>()

const { open } = useDrawer()
const expanded = usePersistentFlag('overview.agents', true)
const now = useNow(10_000)

const yours = computed(() => props.agents.filter((a) => a.kind === 'yours'))
const watchers = computed(() => props.agents.filter((a) => a.kind === 'managed'))
const summary = computed(() => {
  const count = (status: Agent['status']) => props.agents.filter((a) => a.status === status).length
  return `${count('blocked')} waiting · ${count('busy')} busy`
})
</script>

<template>
  <CollapsibleSection v-model:open="expanded" title="Agents" :summary="summary">
    <SideGroupLabel>Your sessions</SideGroupLabel>
    <SideEmpty v-if="!yours.length">No Claude Code sessions running.</SideEmpty>
    <MiniRow v-for="agent in yours" :key="agent.id" @select="open({ type: 'agent', id: agent.id })">
      <template #lead><StatusDot :status="agent.status" /></template>
      <AgentName :agent="agent" class="text-[12.5px]" />
      <template #sub>{{ agent.needs ?? agent.title ?? agent.lastReply }}</template>
    </MiniRow>

    <template v-if="watchers.length">
      <SideGroupLabel>Watchers</SideGroupLabel>
      <MiniRow v-for="agent in watchers" :key="agent.id" @select="open({ type: 'agent', id: agent.id })">
        <template #lead><StatusDot :status="agent.status" /></template>
        {{ agent.name }}
        <template v-if="agent.loops[0]?.nextRunAt" #sub>Next run {{ timeUntil(agent.loops[0].nextRunAt, now) }}</template>
      </MiniRow>
    </template>

    <div class="mt-2.5 flex flex-wrap gap-x-4 text-[12.5px] font-medium text-accent">
      <a href="/agents" class="hover:opacity-80">All agents →</a>
      <a href="/loops" class="hover:opacity-80">All loops →</a>
    </div>
  </CollapsibleSection>
</template>
