<script setup lang="ts">
import { inject, onBeforeUnmount, onMounted, ref } from 'vue'
import { PhMoon } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { request } from '@/lib/api'
import { backAt } from '@/lib/away'
import type { ShellProps } from '@/types/dashboard'

const props = defineProps<{ away: NonNullable<ShellProps['away']>; linkClass: string }>()

const open = ref(false)
const date = ref('')
const error = ref('')
const root = ref<HTMLElement>()
const refreshShell = inject<() => Promise<unknown>>('refreshShell', async () => undefined)
const tomorrow = new Date(Date.now() + 86_400_000).toLocaleDateString('en-CA')

async function go(body: { choice: 'today' | 'date'; date?: string }) {
  error.value = ''
  try {
    await request('PATCH', '/api/away', body)
    open.value = false
    refreshShell()
  } catch (e) {
    error.value = (e as Error).message
  }
}

const outside = (event: MouseEvent) => {
  if (!root.value?.contains(event.target as Node)) open.value = false
}
onMounted(() => document.addEventListener('mousedown', outside))
onBeforeUnmount(() => document.removeEventListener('mousedown', outside))
</script>

<template>
  <div v-if="!props.away.until" ref="root" class="sm:relative" @keydown.esc="open = false">
    <button type="button" :class="linkClass" aria-label="Away" :aria-expanded="open" @click="open = !open">
      <PhMoon :size="15" />
    </button>
    <div v-if="open" role="dialog" aria-label="Away" class="absolute top-full right-0 z-30 mt-2 grid w-72 gap-3 rounded-lg border border-line bg-surface p-4 text-left shadow-xl">
      <div class="grid gap-0.5">
        <p class="text-[13px] font-semibold">Away</p>
        <p class="text-[12.5px] text-muted">Pauses notifications. Anything that comes in meanwhile isn't sent later, and Echo keeps syncing.</p>
      </div>
      <button type="button" class="grid gap-0.5 rounded-md border border-line px-3 py-2 text-left hover:bg-subtle" @click="go({ choice: 'today' })">
        <span class="text-[13px] font-medium">Rest of today</span>
        <span class="text-[12px] text-muted">Back {{ backAt(props.away.restOfToday) }}</span>
      </button>
      <div class="flex items-center gap-2">
        <label class="grid flex-1 gap-1 text-[12px] text-muted">
          Back on
          <input v-model="date" type="date" :min="tomorrow" class="rounded-md border border-line bg-surface px-2 py-1 text-[13px] text-ink" />
        </label>
        <BaseButton class="self-end" :disabled="!date" @click="go({ choice: 'date', date })">Set</BaseButton>
      </div>
      <p v-if="error" class="text-[12px] text-bad">{{ error }}</p>
    </div>
  </div>
</template>
