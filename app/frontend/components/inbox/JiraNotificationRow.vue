<script setup lang="ts">
import { computed } from 'vue'
import BasePill from '@/components/ui/BasePill.vue'
import ListRow from '@/components/ui/ListRow.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { jiraNotificationText } from '@/lib/jiraNotifications'
import { timeAgo } from '@/lib/format'
import { jiraKind } from '@/lib/labels'
import type { JiraNotification } from '@/types/dashboard'

const props = defineProps<{ notification: JiraNotification; now: number }>()

const dashboard = useDashboard()
const { open } = useDrawer()

const ticket = computed(() => dashboard.ticket(props.notification.key))
const summary = computed(() => jiraNotificationText(props.notification))

function select() {
  dashboard.markRead(props.notification.id)
  if (ticket.value) open({ type: 'ticket', key: props.notification.key, notificationId: props.notification.id })
  else if (props.notification.url) window.open(props.notification.url, '_blank', 'noopener')
}
</script>

<template>
  <ListRow :unread="notification.unread" @select="select">
    <template #lead><span class="font-mono text-xs font-medium text-jira">{{ notification.key }}</span></template>
    {{ ticket?.title ?? notification.key }}
    <template #content>{{ summary }}</template>
    <template #meta>
      <BasePill :tone="jiraKind[notification.kind].tone">{{ jiraKind[notification.kind].label }}</BasePill>
      <span>Jira</span>
    </template>
    <template #aside>{{ timeAgo(notification.at, now) }}</template>
  </ListRow>
</template>
