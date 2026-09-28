<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import BaseTooltip from '@/components/ui/BaseTooltip.vue'
import { useNow } from '@/composables/useNow'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'

/** The "Updated Xs ago" light: links to Health, and its tooltip says how each sync is doing. */
const props = defineProps<{ updatedAt: string; refreshFailed?: boolean }>()

interface Sync { source: string; label: string; status: 'ok' | 'stale' | 'failing' | 'not_starting' | 'unknown'; connected: boolean; lastSuccessAt: string | null }
interface Health { scheduler: { stalled: boolean }; syncs: Sync[] }

const REFRESH_MS = 60_000
const WORDS: Record<Sync['status'], string> = { ok: 'healthy', stale: 'behind', failing: 'failing', not_starting: 'not starting', unknown: 'not run yet' }

const health = ref<Health | null>(null)
const now = useNow()
const shown = computed(() => health.value?.syncs?.filter((s) => s.connected) ?? [])

// Red when a sync is failing or the scheduler has stalled, amber when one is behind.
const tone = computed(() => {
  if (props.refreshFailed || health.value?.scheduler?.stalled || shown.value.some((s) => s.status === 'failing' || s.status === 'not_starting')) return 'bad'
  if (shown.value.some((s) => s.status === 'stale')) return 'warn'
  return 'ok'
})
const line = (s: Sync) => `${s.label}: ${WORDS[s.status]}${s.lastSuccessAt ? `, ${timeAgo(s.lastSuccessAt, now.value)} ago` : ''}`
const tooltip = computed(() => {
  if (!health.value) return 'Checking the syncs…'
  const lines = shown.value.map(line)
  if (health.value.scheduler?.stalled) lines.unshift('The scheduler has stalled; Echo is running the syncs itself.')
  return lines.join('\n')
})
const syncTone = (s: Sync) => (s.status === 'failing' || s.status === 'not_starting' ? 'bad' : s.status === 'stale' ? 'warn' : s.status === 'ok' ? 'ok' : 'none')

async function load() {
  health.value = await request<Health>('GET', '/api/health').catch(() => health.value)
}
let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  load()
  timer = setInterval(() => document.visibilityState === 'visible' && load(), REFRESH_MS)
})
onBeforeUnmount(() => clearInterval(timer))

const DOT: Record<string, string> = { ok: 'bg-ok', warn: 'bg-warn', bad: 'bg-bad' }
</script>

<template>
  <BaseTooltip :text="tooltip" placement="bottom" @mouseenter="load">
    <template #tip>
      <span v-if="!health">Checking the syncs…</span>
      <span v-else class="grid gap-1">
        <span v-if="health.scheduler?.stalled">The scheduler has stalled; Echo is running the syncs itself.</span>
        <span v-for="sync in shown" :key="sync.source" class="flex items-center gap-1.5">
          <span :class="['size-1.5 shrink-0 rounded-full', DOT[syncTone(sync)] ?? 'bg-faint']" aria-hidden="true" />
          {{ line(sync) }}
        </span>
      </span>
    </template>
    <a href="/settings#health" class="flex items-center rounded-md hover:bg-subtle" :aria-label="`Sync health. ${tooltip}`">
      <span class="relative ml-2 flex size-2" aria-hidden="true">
        <span v-if="tone === 'ok'" class="absolute inset-0 rounded-full bg-ok opacity-60 motion-safe:animate-ping" />
        <span :class="['relative size-2 rounded-full', DOT[tone]]" />
      </span>
      <span class="px-2 py-1 text-[12.5px] whitespace-nowrap text-muted tabular-nums" aria-live="polite">
        {{ refreshFailed ? "Couldn't refresh" : `Updated ${timeAgo(updatedAt, now)} ago` }}
      </span>
    </a>
  </BaseTooltip>
</template>
