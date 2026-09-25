<script setup lang="ts">
import { computed } from 'vue'
import BasePill from '@/components/ui/BasePill.vue'
import ListRow from '@/components/ui/ListRow.vue'
import UserAvatar from '@/components/ui/UserAvatar.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { timeAgo } from '@/lib/format'
import { githubNotificationText } from '@/lib/githubNotifications'
import { githubReason } from '@/lib/labels'
import type { GithubNotification } from '@/types/dashboard'

const props = defineProps<{ notification: GithubNotification; now: number }>()

const dashboard = useDashboard()
const { open } = useDrawer()

const pr = computed(() => dashboard.pullRequest(props.notification.prKey))
const label = computed(() => githubReason[props.notification.reason] ?? { label: 'Activity', tone: 'neutral' as const })
const summary = computed(() => githubNotificationText(props.notification))

function select() {
  dashboard.markRead(props.notification.id)
  if (pr.value) open({ type: 'pullRequest', key: pr.value.key, notificationId: props.notification.id })
  else if (props.notification.url) window.open(props.notification.url, '_blank', 'noopener')
}
</script>

<template>
  <ListRow :unread="notification.unread" @select="select">
    <template #lead>
      <UserAvatar v-if="notification.actor" :name="notification.actor" />
      <SourceBadge v-else>GH</SourceBadge>
    </template>
    {{ pr?.title ?? notification.title ?? notification.prKey }}
    <template #content>{{ summary }}</template>
    <template #meta>
      <BasePill :tone="label.tone">{{ label.label }}</BasePill>
      <span>{{ notification.prKey.split('/').pop() }}</span>
    </template>
    <template #aside>{{ timeAgo(notification.at, now) }}</template>
  </ListRow>
</template>
