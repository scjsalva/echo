<script setup lang="ts">
import { computed } from 'vue'
import { initials } from '@/lib/format'
import BaseTooltip from './BaseTooltip.vue'

const props = defineProps<{ name: string }>()

const PALETTE = ['#4f52c9', '#1e8a4c', '#a86511', '#c63d3d', '#1f6fe5', '#7a4bc2', '#2b8a8a']
const color = computed(() => PALETTE[[...props.name].reduce((sum, c) => sum + c.charCodeAt(0), 0) % PALETTE.length])
</script>

<template>
  <BaseTooltip :text="name" class="shrink-0">
    <span
      class="inline-grid size-5 place-items-center rounded-full text-[9.5px] font-semibold text-white"
      :style="{ backgroundColor: color }"
      aria-hidden="true"
    >{{ initials(name) }}</span>
  </BaseTooltip>
</template>
