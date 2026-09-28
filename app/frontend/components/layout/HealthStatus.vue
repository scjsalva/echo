<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useNow } from '@/composables/useNow'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'

/**
 * The "Updated Xs ago" light. Hovering it drops down how each connected sync is
 * doing; clicking it opens Health.
 */
const props = defineProps<{ updatedAt: string; refreshFailed?: boolean }>()

interface Sync { source: string; label: string; status: 'ok' | 'stale' | 'failing' | 'not_starting' | 'unknown'; connected: boolean; lastSuccessAt: string | null }
interface Health { scheduler: { stalled: boolean }; syncs: Sync[] }
type Tone = 'ok' | 'warn' | 'bad' | 'none'

const REFRESH_MS = 60_000
const CLOSE_DELAY_MS = 150
const STATUS: Record<Sync['status'], { word: string; tone: Tone }> = {
  ok: { word: 'Up to date', tone: 'ok' },
  stale: { word: 'Behind', tone: 'warn' },
  failing: { word: 'Failing', tone: 'bad' },
  not_starting: { word: 'Not starting', tone: 'bad' },
  unknown: { word: 'Not run yet', tone: 'none' },
}
const DOT: Record<Tone, string> = { ok: 'bg-ok', warn: 'bg-warn', bad: 'bg-bad', none: 'bg-faint' }
const WORD: Record<Tone, string> = { ok: 'text-ok', warn: 'text-warn', bad: 'text-bad', none: 'text-muted' }

const health = ref<Health | null>(null)
const open = ref(false)
const now = useNow()
const shown = computed(() => health.value?.syncs?.filter((s) => s.connected) ?? [])

// Red when a sync is failing or the scheduler has stalled, amber when one is behind.
const tone = computed<Tone>(() => {
  if (props.refreshFailed || health.value?.scheduler?.stalled || shown.value.some((s) => STATUS[s.status]?.tone === 'bad')) return 'bad'
  if (shown.value.some((s) => s.status === 'stale')) return 'warn'
  return 'ok'
})
const summary = computed(() => {
  if (props.refreshFailed) return "This page couldn't refresh"
  if (health.value?.scheduler?.stalled) return 'The scheduler has stalled'
  const troubled = shown.value.filter((s) => STATUS[s.status]?.tone === 'bad' || s.status === 'stale')
  if (!troubled.length) return "Everything's up to date"
  if (troubled.length > 1) return `${troubled.length} syncs need a look`
  return `${troubled[0].label} is ${STATUS[troubled[0].status].word.toLowerCase()}`
})

async function load() {
  health.value = await request<Health>('GET', '/api/health').catch(() => health.value)
}

// Opens on hover, and stays while the pointer moves from the light onto the panel.
let closing: ReturnType<typeof setTimeout> | undefined
function show() {
  clearTimeout(closing)
  if (!open.value) load()
  open.value = true
}
function hide() {
  closing = setTimeout(() => (open.value = false), CLOSE_DELAY_MS)
}

let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  load()
  timer = setInterval(() => document.visibilityState === 'visible' && load(), REFRESH_MS)
})
onBeforeUnmount(() => {
  clearInterval(timer)
  clearTimeout(closing)
})
</script>

<template>
  <div class="relative" @mouseenter="show" @mouseleave="hide" @focusin="show" @focusout="hide" @keydown.esc="open = false">
    <a href="/settings#health" class="flex items-center rounded-md hover:bg-subtle" :aria-expanded="open" :aria-label="`Sync health: ${summary}`">
      <span class="relative ml-2 flex size-2" aria-hidden="true">
        <span v-if="tone === 'ok'" class="absolute inset-0 rounded-full bg-ok opacity-60 motion-safe:animate-ping" />
        <span :class="['relative size-2 rounded-full', DOT[tone]]" />
      </span>
      <span class="px-2 py-1 text-[12.5px] whitespace-nowrap text-muted tabular-nums" aria-live="polite">
        {{ refreshFailed ? "Couldn't refresh" : `Updated ${timeAgo(updatedAt, now)} ago` }}
      </span>
    </a>

    <div
      v-if="open"
      role="dialog"
      aria-label="Sync health"
      class="absolute top-full right-0 z-30 mt-2 grid w-72 overflow-hidden rounded-lg border border-line bg-surface text-left shadow-xl"
    >
      <div class="grid gap-0.5 border-b border-line-soft px-4 py-3">
        <p class="text-[13px] font-semibold">Sync health</p>
        <p :class="['text-[12.5px]', WORD[tone]]">{{ health ? summary : 'Checking…' }}</p>
      </div>
      <p v-if="health?.scheduler?.stalled" class="border-b border-line-soft bg-bad-soft px-4 py-2 text-[12.5px] text-bad">
        Syncs aren't being started on schedule, so Echo is running them itself for now.
      </p>
      <ul v-if="health" class="grid py-1">
        <li v-for="sync in shown" :key="sync.source" class="grid grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-x-2.5 px-4 py-1.5">
          <span :class="['size-2 rounded-full', DOT[STATUS[sync.status]?.tone ?? 'none']]" aria-hidden="true" />
          <span class="grid">
            <span class="text-[13px]">{{ sync.label }}</span>
            <span class="text-[11.5px] text-faint">{{ sync.lastSuccessAt ? `Synced ${timeAgo(sync.lastSuccessAt, now)} ago` : 'Not synced yet' }}</span>
          </span>
          <span :class="['text-[12px] font-medium', WORD[STATUS[sync.status]?.tone ?? 'none']]">{{ STATUS[sync.status]?.word ?? sync.status }}</span>
        </li>
      </ul>
      <a href="/settings#health" class="border-t border-line-soft px-4 py-2.5 text-center text-[12.5px] font-medium text-accent hover:bg-subtle">Open Health →</a>
    </div>
  </div>
</template>
