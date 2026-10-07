<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhFunnel } from '@phosphor-icons/vue'

/** One kind of filter, e.g. Status, with its choices. Several choices in a group match any of them. */
export interface FilterGroup {
  key: string
  label: string
  options: { value: string; label: string; count?: number }[]
}

const props = defineProps<{ groups: FilterGroup[] }>()
const model = defineModel<Record<string, string[]>>({ required: true })

const open = ref(false)
const active = computed(() => Object.values(model.value).reduce((n, values) => n + values.length, 0))
function toggle(group: string, value: string) {
  const current = model.value[group] ?? []
  model.value = { ...model.value, [group]: current.includes(value) ? current.filter((v) => v !== value) : [...current, value] }
}
const clear = () => (model.value = Object.fromEntries(props.groups.map((g) => [g.key, []])))

// Opens on hover like the header's menus, and on a tap where there's no hover. On phones the panel
// anchors to the nearest positioned parent (the toolbar), so it stays on screen wherever the button wraps.
const CLOSE_DELAY_MS = 150
let closing: ReturnType<typeof setTimeout> | undefined
function show() {
  clearTimeout(closing)
  open.value = true
}
function hide() {
  closing = setTimeout(() => (open.value = false), CLOSE_DELAY_MS)
}

const pill = (on: boolean) => [
  'rounded-full border px-2.5 py-1 text-[12.5px]',
  on ? 'border-transparent bg-accent-soft font-medium text-accent' : 'border-line bg-surface text-muted hover:text-ink',
]
</script>

<template>
  <div class="sm:relative" @mouseenter="show" @mouseleave="hide" @focusin="show" @focusout="hide" @keydown.esc="open = false">
    <button type="button" :class="[pill(active > 0), 'inline-flex items-center gap-1.5']" :aria-expanded="open" aria-haspopup="dialog" @click="open = !open">
      <PhFunnel :size="13" :weight="active ? 'fill' : 'regular'" /> Filters
      <span v-if="active" class="font-mono text-[11px] opacity-70">{{ active }}</span>
    </button>
    <div
      v-if="open"
      role="dialog"
      aria-label="Filters"
      class="absolute top-full left-0 z-30 mt-2 grid w-[min(380px,calc(100vw-2rem))] gap-3 rounded-lg border border-line bg-surface p-3 text-left shadow-xl before:absolute before:inset-x-0 before:-top-2 before:h-2"
    >
      <section v-for="group in groups" :key="group.key" class="grid gap-1.5" :aria-label="group.label">
        <h4 class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">{{ group.label }}</h4>
        <p v-if="!group.options.length" class="text-[12.5px] text-faint">Nothing to filter by.</p>
        <div v-else class="flex flex-wrap gap-1.5">
          <button
            v-for="option in group.options"
            :key="option.value"
            type="button"
            :aria-pressed="model[group.key]?.includes(option.value) ?? false"
            :class="pill(model[group.key]?.includes(option.value) ?? false)"
            @click="toggle(group.key, option.value)"
          >
            {{ option.label }}<span v-if="option.count !== undefined" class="ml-1 font-mono text-[11px] opacity-70">{{ option.count }}</span>
          </button>
        </div>
      </section>
      <button v-if="active" type="button" class="justify-self-start text-[12.5px] font-medium text-accent hover:opacity-80" @click="clear">Clear all</button>
    </div>
  </div>
</template>
