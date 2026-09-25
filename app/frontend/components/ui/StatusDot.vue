<script setup lang="ts">
import type { AgentStatus } from '@/types/dashboard'

defineProps<{ status: AgentStatus | 'done' }>()

const classes: Record<AgentStatus | 'done', string> = {
  busy: 'bg-ok',
  running: 'bg-ok',
  blocked: 'bg-warn ring-3 ring-warn-soft',
  idle: 'bg-idle',
  done: 'bg-idle',
}
</script>

<template>
  <span :class="['inline-block size-2 shrink-0 rounded-full', classes[status]]" aria-hidden="true" />
</template>
