<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{ values: number[]; label: string }>()

const WIDTH = 100
const HEIGHT = 40

const points = computed(() => {
  const max = Math.max(...props.values, 1)
  const step = WIDTH / Math.max(props.values.length - 1, 1)
  return props.values.map((v, i) => `${i * step},${HEIGHT - (v / max) * (HEIGHT - 4) - 2}`).join(' ')
})
</script>

<template>
  <svg :viewBox="`0 0 ${WIDTH} ${HEIGHT}`" preserveAspectRatio="none" role="img" :aria-label="label" class="block h-11 w-full">
    <polygon :points="`0,${HEIGHT} ${points} ${WIDTH},${HEIGHT}`" class="fill-accent-soft" />
    <polyline :points="points" fill="none" class="stroke-accent" stroke-width="1.5" vector-effect="non-scaling-stroke" />
  </svg>
</template>
