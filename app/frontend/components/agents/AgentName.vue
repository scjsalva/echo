<script setup lang="ts">
import type { Agent } from '@/types/dashboard'

defineProps<{ agent: Pick<Agent, 'name' | 'handle' | 'renamed'> }>()
</script>

<template>
  <span class="inline-flex min-w-0 flex-wrap items-baseline gap-x-1.5">
    <span :class="['break-words', !agent.renamed && 'font-mono']">{{ agent.name }}</span>
    <span v-if="agent.renamed && agent.handle" class="font-mono text-[11px] font-normal text-faint">{{ agent.handle }}</span>
  </span>
</template>
