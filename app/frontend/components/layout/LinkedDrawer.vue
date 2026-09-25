<script setup lang="ts">
import { onMounted, shallowRef } from 'vue'
import LinkedDrawerBody from './LinkedDrawerBody.vue'
import { request } from '@/lib/api'
import type { DrawerTarget } from '@/composables/useDrawer'
import type { OverviewProps } from '@/types/dashboard'

// The current page may not have loaded what the drawer needs (Settings loads no
// PRs), so the drawer brings its own copy of the dashboard.
const props = defineProps<{ target: DrawerTarget; fallback: string }>()
const emit = defineEmits<{ closed: [] }>()

const data = shallowRef<OverviewProps | null>(null)
onMounted(async () => {
  try {
    data.value = await request<OverviewProps>('GET', '/api/dashboard')
  } catch {
    location.assign(props.fallback)
  }
})
</script>

<template>
  <LinkedDrawerBody v-if="data" :initial="data" :target="target" :fallback="fallback" @closed="emit('closed')" />
</template>
