<script setup lang="ts">
import { computed } from 'vue'
import BasePill from '@/components/ui/BasePill.vue'
import ListRow from '@/components/ui/ListRow.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { timeAgo } from '@/lib/format'
import type { Tone } from '@/lib/labels'
import type { JiraCategory, JiraTicket } from '@/types/dashboard'

const props = defineProps<{ ticket: JiraTicket; now: number }>()

const TONE: Record<JiraCategory, Tone> = { todo: 'neutral', in_progress: 'warn', code_review: 'accent', post_development: 'ok', done: 'ok' }

const dashboard = useDashboard()
const { open } = useDrawer()

// Tickets from a live search don't carry sync-only details, so borrow them when synced.
const synced = computed(() => dashboard.ticket(props.ticket.key))
const updated = computed(() => synced.value?.updated ?? props.ticket.updated)
const mine = computed(() => synced.value?.assignedToMe ?? props.ticket.assignedToMe)
</script>

<template>
  <ListRow @select="open({ type: 'ticket', key: ticket.key, ticket })">
    <template #lead><span class="font-mono text-xs font-medium text-jira">{{ ticket.key }}</span></template>
    {{ ticket.title }}
    <template #meta>
      <BasePill :tone="TONE[ticket.category]">{{ ticket.status }}</BasePill>
      <span v-if="ticket.priority">{{ ticket.priority }}</span>
      <span v-if="ticket.sprint">{{ ticket.sprint }}</span>
      <span v-if="!mine && ticket.assignee">{{ ticket.assignee }}</span>
    </template>
    <template #aside>{{ updated ? timeAgo(updated, now) : '' }}</template>
  </ListRow>
</template>
