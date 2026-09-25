<script setup lang="ts">
defineProps<{ label: string; disabled?: boolean }>()
const model = defineModel<boolean>({ required: true })
</script>

<template>
  <button
    type="button"
    role="switch"
    :aria-checked="model"
    :aria-label="label"
    :disabled="disabled"
    :class="['relative h-5 w-9 shrink-0 rounded-full transition-colors disabled:opacity-50', model ? 'bg-accent' : 'bg-line']"
    @click="model = !model"
  >
    <span :class="['absolute top-0.5 left-0.5 size-4 rounded-full bg-white shadow transition-transform', model && 'translate-x-4']" />
  </button>
</template>
