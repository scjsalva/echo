<script setup lang="ts" generic="T extends string">
defineProps<{ options: readonly { value: T; label: string; count?: number }[]; label: string }>()
const model = defineModel<T>({ required: true })
</script>

<template>
  <div role="radiogroup" :aria-label="label" class="flex flex-wrap gap-1.5">
    <button
      v-for="option in options"
      :key="option.value"
      type="button"
      role="radio"
      :aria-checked="model === option.value"
      :class="[
        'rounded-full border px-2.5 py-1 text-[12.5px]',
        model === option.value ? 'border-transparent bg-accent-soft font-medium text-accent' : 'border-line bg-surface text-muted hover:text-ink',
      ]"
      @click="model = option.value"
    >
      {{ option.label }}<span v-if="option.count !== undefined" class="ml-1 font-mono text-[11px] opacity-70">{{ option.count }}</span>
    </button>
  </div>
</template>
