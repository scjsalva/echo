<script setup lang="ts" generic="T extends string">
import InfoHint from './InfoHint.vue'

defineProps<{ options: readonly { value: T; label: string; hint?: string }[]; label: string }>()
const model = defineModel<T>({ required: true })
</script>

<template>
  <div role="radiogroup" :aria-label="label" class="inline-flex flex-wrap gap-0.5 rounded-lg border border-line bg-subtle p-0.5">
    <!-- The hint sits beside its option, not inside it, so it isn't a button within a button. -->
    <span
      v-for="option in options"
      :key="option.value"
      :class="['inline-flex items-center gap-1 rounded-md', option.hint && 'pr-1.5', model === option.value && 'bg-surface shadow-sm']"
    >
      <button
        type="button"
        role="radio"
        :aria-checked="model === option.value"
        :class="['rounded-md py-1 text-[12.5px]', option.hint ? 'pl-2.5' : 'px-2.5', model === option.value ? 'font-medium text-ink' : 'text-muted hover:text-ink']"
        @click="model = option.value"
      >{{ option.label }}</button>
      <InfoHint v-if="option.hint" :text="option.hint" />
    </span>
  </div>
</template>
