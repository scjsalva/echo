<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import { PhChatText, PhPencilSimple, PhPower, PhSparkle, PhTerminalWindow } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BaseTooltip from '@/components/ui/BaseTooltip.vue'
import BasePill from '@/components/ui/BasePill.vue'
import DetailSection from '@/components/ui/DetailSection.vue'
import QuoteBlock from '@/components/ui/QuoteBlock.vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import SkillPicker from '@/components/ui/SkillPicker.vue'
import SparkLine from '@/components/ui/SparkLine.vue'
import StatusDot from '@/components/ui/StatusDot.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { useFocusTerminal } from '@/composables/useFocusTerminal'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import { useNow } from '@/composables/useNow'
import { formatTokens, timeAgo } from '@/lib/format'
import { describeLoop, loopKind } from '@/lib/loops'
import type { Agent, AgentSummary } from '@/types/dashboard'

const props = defineProps<{ agent: Agent }>()

const { open, close } = useDrawer()
const dashboard = useDashboard()

const renaming = ref(false)
const newName = ref('')
const nameInput = ref<HTMLInputElement>()

async function startRenaming() {
  // Start from the name shown, so renaming is an edit rather than retyping it.
  newName.value = props.agent.renamed ? props.agent.name : (props.agent.title ?? props.agent.name)
  renaming.value = true
  await nextTick()
  nameInput.value?.focus()
}

// Claude Code saves the name itself, so pick it up once it has.
async function rename() {
  try {
    await request('POST', `/api/agents/${props.agent.id}/rename`, { name: newName.value })
    renaming.value = false
    toast.show('Renaming. If the agent is busy, it takes the name when it finishes this turn.')
    setTimeout(() => dashboard.refresh(), 2500)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't rename the agent")
  }
}
const toast = useToast()
const focusTerminal = useFocusTerminal()

const confirmingEnd = ref(false)
const ending = ref(false)

async function endSession() {
  ending.value = true
  try {
    await request('POST', `/api/agents/${props.agent.id}/ending`)
    toast.show('Session ended')
    close()
    dashboard.refresh()
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't end the session")
  } finally {
    ending.value = false
    confirmingEnd.value = false
  }
}
const now = useNow(10_000)

const hasTranscript = computed(() => props.agent.kind !== 'background')
const summary = ref<AgentSummary | null>(null)
const summarising = ref(false)

async function summarise() {
  summarising.value = true
  try {
    summary.value = await request<AgentSummary>('POST', `/api/agents/${props.agent.id}/summary`)
  } catch {
    toast.show("Couldn't summarise this session. Check that claude works in a terminal.")
  } finally {
    summarising.value = false
  }
}

const STATUS_LABEL: Record<Agent['status'], string> = { busy: 'Busy', idle: 'Idle', blocked: 'Waiting on you', running: 'Running' }

const tiles = computed(() => [
  { label: 'today', value: formatTokens(props.agent.tokensToday) },
  { label: 'total', value: formatTokens(props.agent.tokensTotal) },
  { label: 'turns', value: props.agent.turns ?? '—' },
  { label: 'context', value: props.agent.contextPercent ? `${props.agent.contextPercent}%` : '—' },
])
</script>

<template>
  <SideDrawer :label="agent.name">
    <template #eyebrow>
      <StatusDot :status="agent.status" />
      <BasePill :tone="agent.status === 'blocked' ? 'warn' : agent.status === 'idle' ? 'neutral' : 'ok'">{{ STATUS_LABEL[agent.status] }}</BasePill>
      <BasePill tone="accent">{{ agent.model }}</BasePill>
      <span class="font-mono text-xs text-faint">{{ agent.handle ?? agent.name }} · {{ agent.cwd }} · up {{ timeAgo(agent.started, now) }}</span>
    </template>
    <template #title>
      <form v-if="renaming" class="flex flex-wrap items-center gap-2" @submit.prevent="rename">
        <input
          ref="nameInput"
          v-model="newName"
          maxlength="80"
          aria-label="Agent name"
          class="min-w-0 flex-1 rounded-md border border-line bg-surface px-2.5 py-1 text-base font-semibold"
          @keydown.esc.stop="renaming = false"
        />
        <BaseButton variant="primary" size="sm" :disabled="!newName.trim()" @click="rename">Save</BaseButton>
        <BaseButton size="sm" @click="renaming = false">Cancel</BaseButton>
      </form>
      <span v-else class="inline-flex items-start gap-2">
        {{ agent.renamed ? agent.name : (agent.title ?? agent.name) }}
        <BaseTooltip :text="agent.terminalUnavailable ?? 'Rename it with /rename, so the name stays with the session'">
          <button
            type="button"
            class="mt-0.5 rounded-md p-1 text-faint hover:bg-subtle hover:text-ink disabled:opacity-40"
            :disabled="Boolean(agent.terminalUnavailable)"
            aria-label="Rename agent"
            @click="startRenaming"
          >
            <PhPencilSimple :size="14" />
          </button>
        </BaseTooltip>
      </span>
    </template>
    <template #actions>
      <template v-if="hasTranscript">
        <BaseButton class="ai-border" :disabled="summarising" tooltip="Asks Haiku for a short summary of where this session is. Uses a few thousand tokens." @click="summarise">
          <PhSparkle :size="14" weight="fill" class="ai-icon" /> {{ summarising ? 'Summarising…' : 'Summarise' }}
        </BaseButton>
        <BaseButton @click="open({ type: 'transcript', id: agent.id, title: agent.title ?? agent.name })"><PhChatText :size="14" /> Transcript</BaseButton>
        <SkillPicker action="summary" class="basis-full" />
      </template>
      <BaseButton
        :disabled="Boolean(agent.terminalUnavailable)"
        :tooltip="agent.terminalUnavailable ?? 'Brings this session\'s Terminal tab to the front'"
        @click="focusTerminal(agent.id)"
      >
        <PhTerminalWindow :size="14" /> Show terminal
      </BaseButton>
      <template v-if="agent.kind !== 'background'">
        <span v-if="confirmingEnd" class="inline-flex flex-wrap items-center gap-2 rounded-md bg-bad-soft px-2 py-1 text-[12.5px] text-bad">
          End this session? Unsaved work in it stops.
          <BaseButton size="sm" :disabled="ending" class="border-bad! text-bad!" @click="endSession">{{ ending ? 'Ending…' : 'End session' }}</BaseButton>
          <BaseButton size="sm" @click="confirmingEnd = false">Cancel</BaseButton>
        </span>
        <BaseButton v-else tooltip="Quits this Claude Code session, as if you'd exited it in its terminal" @click="confirmingEnd = true">
          <PhPower :size="14" /> End session
        </BaseButton>
      </template>
    </template>

    <p v-if="agent.task" class="rounded-lg bg-accent-soft px-3 py-2.5 text-[13px] text-accent">
      Started by Echo for {{ agent.task.label.toLowerCase() }}<template v-if="agent.task.ref"> on {{ agent.task.ref }}</template>. It ends on its own when the run finishes.
    </p>

    <p v-if="agent.needs" class="rounded-lg bg-warn-soft px-3 py-2.5 font-medium text-warn">{{ agent.needs }}</p>

    <DetailSection v-if="summary" :title="`AI summary · ${summary.model} · ${timeAgo(summary.generatedAt, now)} ago`">
      <QuoteBlock accent>{{ summary.text }}</QuoteBlock>
    </DetailSection>

    <DetailSection v-if="agent.summary" title="Claude's recap">
      <QuoteBlock accent>{{ agent.summary }}</QuoteBlock>
    </DetailSection>

    <DetailSection v-if="agent.lastPrompt" title="Last prompt">
      <QuoteBlock>{{ agent.lastPrompt }}</QuoteBlock>
    </DetailSection>

    <DetailSection v-if="agent.lastReply" :title="`Last reply · ${timeAgo(agent.active, now)} ago`">
      <QuoteBlock>{{ agent.lastReply }}</QuoteBlock>
    </DetailSection>

    <DetailSection title="Usage">
      <div class="grid grid-cols-2 gap-px overflow-hidden rounded-lg border border-line-soft bg-line-soft sm:grid-cols-4">
        <div v-for="tile in tiles" :key="tile.label" class="bg-surface px-3 py-2.5">
          <div class="font-mono text-base font-medium tabular-nums">{{ tile.value }}</div>
          <div class="text-[11px] text-faint">{{ tile.label }}</div>
        </div>
      </div>
      <SparkLine class="mt-2" :values="agent.hourlyTokens" label="Tokens per hour over the last 12 hours" />
    </DetailSection>

    <DetailSection v-if="agent.loops.length" title="Loops">
      <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
        <li v-for="loop in agent.loops" :key="loop.id" class="grid gap-1 px-3 py-2.5">
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-[13px] font-medium break-words">{{ loop.description }}</span>
            <BasePill class="ml-auto">{{ loopKind[loop.kind] }}</BasePill>
          </div>
          <span class="text-[12.5px] text-muted">{{ describeLoop(loop, now) }}</span>
        </li>
      </ul>
    </DetailSection>

    <DetailSection v-if="agent.subagents.length" title="Subagents">
      <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
        <li v-for="sub in agent.subagents" :key="`${sub.type}-${sub.active}`" class="grid gap-1 px-3 py-2.5">
          <div class="flex items-center gap-2">
            <span class="font-mono text-[12.5px] font-medium">{{ sub.type }}</span>
            <span v-if="sub.name" class="min-w-0 text-[12.5px] break-words text-muted">{{ sub.name }}</span>
            <BasePill class="ml-auto" :tone="sub.status === 'running' ? 'ok' : 'neutral'">{{ sub.status }}</BasePill>
          </div>
          <span class="text-[12.5px] text-muted">{{ sub.result }}</span>
        </li>
      </ul>
    </DetailSection>

    <DetailSection v-if="agent.jobs.length" title="Jobs">
      <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
        <li v-for="job in agent.jobs" :key="job.detail" class="flex items-center gap-2 px-3 py-2.5 text-[13px]">
          {{ job.detail }}<BasePill class="ml-auto" tone="warn">{{ job.state }}</BasePill>
        </li>
      </ul>
    </DetailSection>
  </SideDrawer>
</template>
