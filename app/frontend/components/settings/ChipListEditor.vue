<script setup lang="ts">
import { computed, ref, useId } from 'vue'
import { PhPlus, PhX } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'

type Suggestion = { value: string; label?: string | null }

const props = defineProps<{ items: string[]; suggestions: (string | Suggestion)[]; placeholder: string; label: string }>()
const emit = defineEmits<{ change: [items: string[]] }>()

const LIMIT = 10
const draft = ref('')
const open = ref(false)
const active = ref(0)
const listId = useId()

// Top 10 to start with, then the top 10 matching the value or label as you type.
const matches = computed(() => {
  const q = draft.value.trim().toLowerCase()
  return props.suggestions
    .map((s): Suggestion => (typeof s === 'string' ? { value: s } : s))
    .filter((s) => !props.items.includes(s.value) && (!q || `${s.value} ${s.label ?? ''}`.toLowerCase().includes(q)))
    .slice(0, LIMIT)
})

function add(value = draft.value.trim()) {
  if (value && !props.items.includes(value)) emit('change', [...props.items, value])
  draft.value = ''
  active.value = 0
}

function onEnter() {
  add(open.value && matches.value[active.value] ? matches.value[active.value].value : undefined)
}

function move(step: number) {
  open.value = true
  active.value = (active.value + step + matches.value.length) % Math.max(matches.value.length, 1)
}
</script>

<template>
  <div class="grid gap-2">
    <ul v-if="items.length" class="flex flex-wrap gap-1.5" :aria-label="label">
      <li v-for="item in items" :key="item" class="inline-flex items-center gap-1 rounded-full border border-line bg-subtle py-0.5 pr-1 pl-2.5 text-[12.5px]">
        {{ item }}
        <button type="button" class="rounded-full p-0.5 text-faint hover:bg-bad-soft hover:text-bad" :aria-label="`Remove ${item}`" @click="emit('change', items.filter((i) => i !== item))">
          <PhX :size="11" />
        </button>
      </li>
    </ul>
    <form class="flex flex-wrap gap-2" @submit.prevent="onEnter">
      <div class="relative min-w-56 flex-1">
        <input
          v-model="draft"
          :placeholder="placeholder"
          :aria-label="`Add to ${label}`"
          role="combobox"
          :aria-expanded="open && matches.length > 0"
          :aria-controls="listId"
          autocomplete="off"
          class="w-full rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px] placeholder:text-faint"
          @focus="open = true"
          @input="(open = true), (active = 0)"
          @blur="open = false"
          @keydown.down.prevent="move(1)"
          @keydown.up.prevent="move(-1)"
          @keydown.esc="open = false"
        />
        <ul
          v-if="open && matches.length"
          :id="listId"
          role="listbox"
          class="absolute inset-x-0 top-full z-20 mt-1 max-h-72 overflow-y-auto rounded-md border border-line bg-surface py-1 shadow-lg"
        >
          <li
            v-for="(s, i) in matches"
            :key="s.value"
            role="option"
            :aria-selected="i === active"
            :class="['flex cursor-pointer items-baseline gap-2 px-2.5 py-1.5 text-[13px]', i === active && 'bg-subtle']"
            @mousedown.prevent="add(s.value)"
            @mouseenter="active = i"
          >
            <span class="font-medium">{{ s.value }}</span>
            <span v-if="s.label" class="min-w-0 break-words text-muted">{{ s.label }}</span>
          </li>
        </ul>
      </div>
      <BaseButton :disabled="!draft.trim()" @click="add()"><PhPlus :size="14" /> Add</BaseButton>
    </form>
  </div>
</template>
