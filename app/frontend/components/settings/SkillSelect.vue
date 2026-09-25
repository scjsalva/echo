<script setup lang="ts">
import { computed } from 'vue'
import type { SkillOption } from '@/types/dashboard'

const props = defineProps<{ options: SkillOption[]; modelValue: string | null; label: string; inheritLabel?: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string | null] }>()

const SOURCES: Record<SkillOption['source'], string> = { echo: "Echo's", user: 'Yours (~/.claude/skills)', repo: "This repo's (.claude/skills)" }
const groups = computed(() =>
  (Object.keys(SOURCES) as SkillOption['source'][])
    .map((source) => ({ source, label: SOURCES[source], options: props.options.filter((o) => o.source === source) }))
    .filter((g) => g.options.length),
)
</script>

<template>
  <select
    :value="modelValue ?? ''"
    :aria-label="label"
    class="rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
    @change="emit('update:modelValue', ($event.target as HTMLSelectElement).value || null)"
  >
    <option v-if="inheritLabel" value="">{{ inheritLabel }}</option>
    <optgroup v-for="group in groups" :key="group.source" :label="group.label">
      <option v-for="option in group.options" :key="option.id" :value="option.id" :title="option.description">{{ option.name }}</option>
    </optgroup>
  </select>
</template>
