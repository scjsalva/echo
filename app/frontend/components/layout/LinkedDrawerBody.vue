<script setup lang="ts">
import { onMounted, watch } from 'vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer, type DrawerTarget } from '@/composables/useDrawer'
import { needsAction } from '@/lib/notificationState'
import type { OverviewProps } from '@/types/dashboard'

const props = defineProps<{ initial: OverviewProps; target: DrawerTarget; fallback: string }>()
const emit = defineEmits<{ closed: [] }>()

const dashboard = provideDashboard(props.initial)
const drawer = provideDrawer()

onMounted(() => {
  const t = props.target
  const found = t.type === 'agent' ? dashboard.agent(t.id) : t.type === 'pullRequest' ? dashboard.pullRequest(t.key) : t.type === 'ticket' ? dashboard.ticket(t.key) : undefined
  // Not synced any more: its own page knows where else to send you.
  if (!found) return location.assign(props.fallback)

  if ('notificationId' in t && t.notificationId) {
    const n = dashboard.githubNotification(t.notificationId) ?? dashboard.jiraNotification(t.notificationId)
    if (n && !needsAction(n)) dashboard.markRead(t.notificationId)
  }
  drawer.open(t)
})
watch(drawer.target, (now, before) => before && !now && emit('closed'))
</script>

<template>
  <DrawerHost />
</template>
