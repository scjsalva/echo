<script setup lang="ts">
import { computed } from 'vue'
import { padCount } from '@/lib/format'
import InfoHint from './InfoHint.vue'

const props = withDefaults(
  defineProps<{ value: number | string; label: string; suffix?: string; tone?: 'default' | 'accent' | 'warn'; hint?: string }>(),
  { tone: 'default' },
)

const parts = computed(() => (typeof props.value === 'number' ? padCount(props.value) : ['', props.value]))
</script>

<template>
  <div class="flex min-w-0 flex-col gap-1">
    <span
      :class="[
        'font-mono text-[28px] leading-none font-medium tracking-tight tabular-nums',
        { 'text-accent': tone === 'accent', 'text-warn': tone === 'warn' },
      ]"
    ><span :class="tone === 'default' ? 'text-muted/70' : 'opacity-55'">{{ parts[0] }}</span>{{ parts[1] }}{{ suffix }}</span>
    <span class="flex items-center gap-1 text-xs whitespace-nowrap text-muted">{{ label }}<InfoHint v-if="hint" :text="hint" /></span>
  </div>
</template>
