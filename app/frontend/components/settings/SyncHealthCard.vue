<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { PhArrowClockwise } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import SettingRow from './SettingRow.vue'
import { useNow } from '@/composables/useNow'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'
import type { Tone } from '@/lib/labels'

interface Sync {
  source: string
  label: string
  status: 'ok' | 'stale' | 'failing' | 'unknown'
  lastSuccessAt: string | null
  lastAttemptAt: string | null
  lastError: string | null
  lastErrorAt: string | null
  failures: number
}
interface Health {
  scheduler: { lastRunAt: string | null; stalled: boolean; coveringSince: string | null }
  syncs: Sync[]
}

const REFRESH_MS = 10_000
const STATUS: Record<Sync['status'], { label: string; tone: Tone }> = {
  ok: { label: 'Healthy', tone: 'ok' },
  stale: { label: 'Behind', tone: 'warn' },
  failing: { label: 'Failing', tone: 'bad' },
  unknown: { label: 'Not run yet', tone: 'neutral' },
}

const health = ref<Health | null>(null)
const syncing = ref(new Set<string>())
const now = useNow(10_000)
const toast = useToast()

async function load() {
  health.value = await request<Health>('GET', '/api/health').catch(() => health.value)
}

// Sync now: starts it straight away, alongside the automatic runs.
async function syncNow(sync: Sync) {
  syncing.value = new Set([...syncing.value, sync.source])
  try {
    await request('PATCH', `/api/health?source=${sync.source}`)
    toast.show(`${sync.label} started`)
    setTimeout(load, 5_000)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't start it")
  } finally {
    setTimeout(() => (syncing.value = new Set([...syncing.value].filter((s) => s !== sync.source))), 5_000)
  }
}

let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => {
  load()
  timer = setInterval(() => document.visibilityState === 'visible' && load(), REFRESH_MS)
})
onBeforeUnmount(() => clearInterval(timer))
</script>

<template>
  <p v-if="!health" class="py-3 text-[13px] text-faint">Checking…</p>
  <template v-else>
    <SettingRow>
      <template #title>
        Background scheduler
        <BasePill :tone="health.scheduler.stalled ? 'bad' : 'ok'">{{ health.scheduler.stalled ? 'Stalled' : 'Running' }}</BasePill>
      </template>
      <template #description>
        <template v-if="health.scheduler.stalled">
          It stopped starting the syncs<template v-if="health.scheduler.lastRunAt"> {{ timeAgo(health.scheduler.lastRunAt, now) }} ago</template>. Echo is running them
          itself<template v-if="health.scheduler.coveringSince"> since {{ timeAgo(health.scheduler.coveringSince, now) }} ago</template>, and restarts
          the scheduler if it stays stuck.
        </template>
        <template v-else>Starts the syncs below on schedule. Last started one {{ health.scheduler.lastRunAt ? `${timeAgo(health.scheduler.lastRunAt, now)} ago` : 'never' }}.</template>
      </template>
    </SettingRow>

    <SettingRow v-for="sync in health.syncs" :key="sync.source">
      <template #title>
        {{ sync.label }}
        <BasePill :tone="STATUS[sync.status].tone">{{ STATUS[sync.status].label }}</BasePill>
      </template>
      <template #description>
        {{ sync.lastSuccessAt ? `Last succeeded ${timeAgo(sync.lastSuccessAt, now)} ago.` : "Hasn't succeeded yet." }}
        <span v-if="sync.failures" class="text-bad">
          Failed {{ sync.failures }} time{{ sync.failures === 1 ? '' : 's' }} in a row, last {{ sync.lastErrorAt ? `${timeAgo(sync.lastErrorAt, now)} ago` : '' }}: {{ sync.lastError }}
          It retries on its own.
        </span>
      </template>
      <BaseButton :disabled="syncing.has(sync.source)" tooltip="Runs it now, on top of the automatic runs" @click="syncNow(sync)">
        <PhArrowClockwise :size="14" /> {{ syncing.has(sync.source) ? 'Syncing…' : 'Sync now' }}
      </BaseButton>
    </SettingRow>
  </template>
</template>
