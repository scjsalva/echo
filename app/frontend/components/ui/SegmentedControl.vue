<script setup lang="ts" generic="T extends string">
defineProps<{ options: readonly { value: T; label: string }[]; label: string }>()
const model = defineModel<T>({ required: true })
</script>

<template>
  <div role="radiogroup" :aria-label="label" class="inline-flex flex-wrap gap-0.5 rounded-lg border border-line bg-subtle p-0.5">
    <button
      v-for="option in options"
      :key="option.value"
      type="button"
      role="radio"
      :aria-checked="model === option.value"
      :class="[
        'rounded-md px-2.5 py-1 text-[12.5px]',
        model === option.value ? 'bg-surface font-medium text-ink shadow-sm' : 'text-muted hover:text-ink',
      ]"
      @click="model = option.value"
    >{{ option.label }}</button>
  </div>
</template>
