<script setup lang="ts">
import { inject } from 'vue'
import { PhMoon } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { request } from '@/lib/api'
import { backAt } from '@/lib/away'

defineProps<{ until: string }>()

const refreshShell = inject<() => Promise<unknown>>('refreshShell', async () => undefined)

async function back() {
  await request('DELETE', '/api/away')
  refreshShell()
}
</script>

<template>
  <div role="status" class="mb-5 flex flex-wrap items-center gap-x-3 gap-y-2 rounded-lg border border-line bg-subtle px-4 py-2.5 text-[13px]">
    <PhMoon :size="15" class="text-accent" />
    <span class="mr-auto"><span class="font-medium">Away until {{ backAt(until) }}.</span> <span class="text-muted">Notifications are paused.</span></span>
    <BaseButton size="sm" @click="back">I'm back</BaseButton>
  </div>
</template>
