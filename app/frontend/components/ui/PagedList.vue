<script setup lang="ts" generic="T">
import { onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue'
import BaseButton from './BaseButton.vue'

/**
 * Loads a list a page at a time behind a "Load more" button. `load` gets what's
 * already loaded (so callers can derive their own cursor) and returns the next
 * page. Changing `resetKey` starts over, e.g. when a filter or search changes.
 */
const props = withDefaults(
  defineProps<{
    load: (loaded: T[]) => Promise<{ items: T[]; more: boolean }>
    resetKey?: unknown
    loadingText?: string
    /** How long to wait for typing to stop before starting over; 0 for instant, e.g. local filters. */
    resetDelay?: number
  }>(),
  { resetKey: undefined, loadingText: 'Loading…', resetDelay: 300 },
)

defineSlots<{ default(props: { items: T[]; done: boolean }): unknown }>()

const items = ref([]) as Ref<T[]>
const more = ref(true)
const loading = ref(false)
const failed = ref<string | null>(null)
let generation = 0

async function loadMore() {
  if (loading.value || !more.value) return
  loading.value = true
  const current = generation
  try {
    const page = await props.load(items.value)
    if (current !== generation) return
    items.value = [...items.value, ...page.items]
    more.value = page.more
    failed.value = null
  } catch (error) {
    if (current === generation) failed.value = error instanceof Error ? error.message : "Couldn't load more"
  } finally {
    if (current === generation) loading.value = false
  }
}

function reset() {
  generation++
  items.value = []
  more.value = true
  loading.value = false
  failed.value = null
  loadMore()
}

let debounce: ReturnType<typeof setTimeout> | undefined
// Compared by value: callers pass a fresh array on every render, and a live
// refresh re-rendering the page mustn't throw away what's been loaded.
watch(
  () => JSON.stringify(props.resetKey),
  () => {
    clearTimeout(debounce)
    if (props.resetDelay) debounce = setTimeout(reset, props.resetDelay)
    else reset()
  },
)
onMounted(loadMore)
onBeforeUnmount(() => clearTimeout(debounce))
</script>

<template>
  <div>
    <slot :items="items" :done="!more && !loading" />
    <div class="flex justify-center py-3 text-[12.5px] text-faint">
      <span v-if="loading">{{ loadingText }}</span>
      <span v-else-if="failed" class="flex items-center gap-2">
        {{ failed }}
        <BaseButton size="sm" @click="loadMore">Try again</BaseButton>
      </span>
      <BaseButton v-else-if="more" size="sm" @click="loadMore">Load more</BaseButton>
    </div>
  </div>
</template>
