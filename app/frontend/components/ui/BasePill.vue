<script setup lang="ts">
import type { Tone } from '@/lib/labels'

withDefaults(defineProps<{ tone?: Tone }>(), { tone: 'neutral' })

const tones: Record<Tone, string> = {
  neutral: 'bg-subtle text-muted',
  accent: 'bg-accent-soft text-accent',
  ok: 'bg-ok-soft text-ok',
  warn: 'bg-warn-soft text-warn',
  bad: 'bg-bad-soft text-bad',
}
</script>

<template>
  <span :class="['inline-flex items-center gap-1 whitespace-nowrap rounded-full px-2 py-px text-[11.5px] font-medium', tones[tone]]">
    <slot />
  </span>
</template>
