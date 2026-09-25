<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhArrowSquareOut, PhBellSlash, PhTerminalWindow } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import DetailSection from '@/components/ui/DetailSection.vue'
import QuoteBlock from '@/components/ui/QuoteBlock.vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import NotificationContext from './NotificationContext.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { useFocusTerminal } from '@/composables/useFocusTerminal'
import { useToast } from '@/composables/useToast'
import { sourceBadge } from '@/lib/waiting'
import type { WaitingItem } from '@/types/dashboard'

const props = defineProps<{ item: WaitingItem }>()

const dashboard = useDashboard()
const { open, close } = useDrawer()
const toast = useToast()
const focusTerminal = useFocusTerminal()
const dismissing = ref(false)

const agent = computed(() => (props.item.ref.agentId ? dashboard.agent(props.item.ref.agentId) : undefined))
const pr = computed(() => (props.item.ref.prKey ? dashboard.pullRequest(props.item.ref.prKey) : undefined))
const ticket = computed(() => (props.item.ref.ticketKey ? dashboard.ticket(props.item.ref.ticketKey) : undefined))

const contextText = computed(() => {
  if (props.item.kind === 'review_requested') return 'asked you to review'
  if (props.item.kind === 'assigned') return 'assigned it to you'
  return props.item.detail ? `“${props.item.detail}”` : ''
})

async function dismiss() {
  dismissing.value = true
  try {
    await dashboard.dismiss(props.item.key)
    close()
    toast.show('Dismissed. Later activity on this thread only shows in notifications.')
  } catch {
    toast.show("Couldn't dismiss it. Try again.")
  } finally {
    dismissing.value = false
  }
}
</script>

<template>
  <SideDrawer :label="item.title">
    <template #eyebrow>
      <SourceBadge :tone="item.source === 'jira' ? 'jira' : 'default'">{{ sourceBadge[item.source] }}</SourceBadge>
      <span class="text-xs text-faint">{{ item.label }}</span>
    </template>
    <template #title>{{ item.title }}</template>
    <template #actions>
      <template v-if="agent">
        <BaseButton
          variant="primary"
          :disabled="Boolean(agent.terminalUnavailable)"
          :tooltip="agent.terminalUnavailable ?? undefined"
          @click="focusTerminal(agent.id)"
        >
          <PhTerminalWindow :size="14" /> Show terminal
        </BaseButton>
        <BaseButton @click="open({ type: 'agent', id: agent.id })">Open agent</BaseButton>
      </template>
      <template v-if="pr">
        <BaseButton @click="open({ type: 'pullRequest', key: pr.key, notificationId: item.ref.notificationId })">Open PR</BaseButton>
        <BaseButton :href="pr.url">GitHub <PhArrowSquareOut :size="14" /></BaseButton>
      </template>
      <template v-if="ticket">
        <BaseButton @click="open({ type: 'ticket', key: ticket.key, notificationId: item.ref.notificationId })">Open ticket</BaseButton>
        <BaseButton :href="ticket.url">Jira <PhArrowSquareOut :size="14" /></BaseButton>
      </template>
    </template>

    <DetailSection v-if="agent" title="Agent's last reply">
      <QuoteBlock>{{ agent.lastReply }}</QuoteBlock>
    </DetailSection>
    <NotificationContext v-else :label="item.label" :actor="item.actor" :at="item.at" :text="contextText" />

    <DetailSection v-if="pr" :title="`${pr.repo}#${pr.number}`">
      <QuoteBlock>{{ pr.summary }}</QuoteBlock>
    </DetailSection>
    <DetailSection v-if="ticket" :title="`${ticket.key} · ${ticket.status}`">
      <QuoteBlock>{{ ticket.description }}</QuoteBlock>
    </DetailSection>

    <footer class="flex flex-wrap items-center gap-3 border-t border-line-soft pt-4">
      <BaseButton :disabled="dismissing" @click="dismiss"><PhBellSlash :size="14" /> Dismiss</BaseButton>
      <p class="basis-full max-w-prose text-[12.5px] text-faint">
        {{ item.clears }} Dismiss mutes this thread: later activity still reaches your notifications, but it won't come back here.
      </p>
    </footer>
  </SideDrawer>
</template>
