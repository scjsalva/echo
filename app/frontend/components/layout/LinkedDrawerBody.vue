<script setup lang="ts">
import { onMounted, watch } from 'vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer, type DrawerTarget } from '@/composables/useDrawer'
import type { OverviewProps } from '@/types/dashboard'

const props = defineProps<{ initial: OverviewProps; target: DrawerTarget; fallback: string }>()
const emit = defineEmits<{ closed: [] }>()

const dashboard = provideDashboard(props.initial)
const drawer = provideDrawer()

onMounted(() => {
  const t = props.target
  // A PR the drawer fetches itself when it isn't synced; anything else not synced
  // any more goes to its own page, which knows where else to send you.
  const found = t.type === 'pullRequest' || (t.type === 'agent' ? dashboard.agent(t.id) : t.type === 'ticket' ? dashboard.ticket(t.key) : undefined)
  if (!found) return location.assign(props.fallback)

  // Opening one is a deliberate look, so it's read, even if it still waits on you
  // (that stays in Waiting on you until it's done or dismissed).
  if ('notificationId' in t && t.notificationId) dashboard.markRead(t.notificationId)
  drawer.open(t)
})
watch(drawer.target, (now, before) => before && !now && emit('closed'))
</script>

<template>
  <DrawerHost />
</template>
