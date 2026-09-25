<script setup lang="ts">
import { PhCaretRight } from '@phosphor-icons/vue'

defineProps<{ title: string; summary?: string }>()
const open = defineModel<boolean>('open', { default: true })
</script>

<template>
  <details
    class="group rounded-[10px] border border-line bg-surface"
    :open="open"
    @toggle="open = ($event.target as HTMLDetailsElement).open"
  >
    <summary class="flex cursor-pointer list-none items-center gap-2 rounded-[10px] px-3.5 py-3 hover:bg-subtle [&::-webkit-details-marker]:hidden">
      <PhCaretRight :size="12" weight="bold" class="text-faint transition-transform group-open:rotate-90" />
      <h3 class="text-[13.5px] font-semibold">{{ title }}</h3>
      <span v-if="summary" class="ml-auto text-xs text-faint">{{ summary }}</span>
    </summary>
    <div class="grid gap-px border-t border-line-soft px-3.5 pb-3"><slot /></div>
  </details>
</template>
