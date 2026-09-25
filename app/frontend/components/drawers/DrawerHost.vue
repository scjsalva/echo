<script setup lang="ts">
import { computed } from 'vue'
import AgentDrawer from './AgentDrawer.vue'
import PullRequestDrawer from './PullRequestDrawer.vue'
import TicketDrawer from './TicketDrawer.vue'
import TranscriptDrawer from './TranscriptDrawer.vue'
import WaitingItemDrawer from './WaitingItemDrawer.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'

const dashboard = useDashboard()
const { target } = useDrawer()

const agent = computed(() => (target.value?.type === 'agent' ? dashboard.agent(target.value.id) : undefined))
const pr = computed(() => (target.value?.type === 'pullRequest' ? dashboard.pullRequest(target.value.key) : undefined))
// Tickets outside the synced set (e.g. older done ones) travel with the target.
const ticket = computed(() => (target.value?.type === 'ticket' ? (dashboard.ticket(target.value.key) ?? target.value.ticket) : undefined))
const waiting = computed(() => (target.value?.type === 'waiting' ? dashboard.waitingItem(target.value.key) : undefined))
const notificationId = computed(() =>
  target.value && 'notificationId' in target.value ? target.value.notificationId : undefined,
)
</script>

<template>
  <AgentDrawer v-if="agent" :key="agent.id" :agent="agent" />
  <PullRequestDrawer v-else-if="pr" :key="pr.key" :pr="pr" :notification-id="notificationId" />
  <TicketDrawer v-else-if="ticket" :key="ticket.key" :ticket="ticket" :notification-id="notificationId" />
  <WaitingItemDrawer v-else-if="waiting" :key="waiting.key" :item="waiting" />
  <TranscriptDrawer v-else-if="target?.type === 'transcript'" :id="target.id" :key="target.id" :title="target.title" />
</template>
