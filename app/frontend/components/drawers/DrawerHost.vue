<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import AgentDrawer from './AgentDrawer.vue'
import PullRequestDrawer from './PullRequestDrawer.vue'
import TicketDrawer from './TicketDrawer.vue'
import TranscriptDrawer from './TranscriptDrawer.vue'
import WaitingItemDrawer from './WaitingItemDrawer.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { PullRequest } from '@/types/dashboard'

const dashboard = useDashboard()
const { target, close } = useDrawer()
const toast = useToast()

const agent = computed(() => (target.value?.type === 'agent' ? dashboard.agent(target.value.id) : undefined))
// PRs outside the sync (merged, closed, or not in your queue) are fetched from GitHub.
const fetched = ref<PullRequest>()
const pr = computed(() => {
  if (target.value?.type !== 'pullRequest') return undefined
  const key = target.value.key
  return dashboard.pullRequest(key) ?? (fetched.value?.key === key ? fetched.value : undefined)
})
watch(
  () => (target.value?.type === 'pullRequest' ? target.value.key : null),
  async (key) => {
    if (!key || dashboard.pullRequest(key) || fetched.value?.key === key) return
    const [repo, number] = key.split('#')
    try {
      fetched.value = await request<PullRequest>('GET', `/api/github/pull_requests/${repo}/${number}`)
    } catch {
      toast.show(`Couldn't load ${key} from GitHub`)
      close()
    }
  },
  { immediate: true },
)
// Tickets outside the synced set (e.g. older done ones) travel with the target.
const ticket = computed(() => (target.value?.type === 'ticket' ? (dashboard.ticket(target.value.key) ?? target.value.ticket) : undefined))
const waiting = computed(() => (target.value?.type === 'waiting' ? dashboard.waitingItem(target.value.key) : undefined))
const notificationId = computed(() =>
  target.value && 'notificationId' in target.value ? target.value.notificationId : undefined,
)
// Opened from Waiting on you, or from a notification that's waiting on you (the bell,
// the inbox, an OS notification): the drawer offers to dismiss it, under the message.
const fromWaiting = computed(() => {
  const key = target.value && 'waitingKey' in target.value ? target.value.waitingKey : undefined
  if (key) return dashboard.waitingItem(key)
  const id = notificationId.value
  return id ? dashboard.waitingFor(id) : undefined
})
</script>

<template>
  <AgentDrawer v-if="agent" :key="agent.id" :agent="agent" :waiting="fromWaiting" />
  <PullRequestDrawer v-else-if="pr" :key="pr.key" :pr="pr" :notification-id="notificationId" :waiting="fromWaiting" />
  <TicketDrawer v-else-if="ticket" :key="ticket.key" :ticket="ticket" :notification-id="notificationId" :waiting="fromWaiting" />
  <WaitingItemDrawer v-else-if="waiting" :key="waiting.key" :item="waiting" />
  <TranscriptDrawer v-else-if="target?.type === 'transcript'" :id="target.id" :key="target.id" :title="target.title" />
</template>
