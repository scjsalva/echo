<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { request } from '@/lib/api'
import { wakeProgress, type WakeState, type WakeSync } from '@/lib/wakeProgress'

/**
 * After the Mac sleeps a while, covers the page until Echo has caught up:
 * while it restarts (if it needs to), then as each sync runs again.
 */
interface Health { scheduler: { restartedAt: string | null }; syncs: WakeSync[] }

const TICK_MS = 5_000
const POLL_MS = 3_000
// A gap this long between ticks means the Mac slept (or the tab was frozen).
const PAUSE_MS = 10 * 60_000
// Echo restarting itself this recently, with syncs still to run, is shown too.
const RECENT_RESTART_MS = 5 * 60_000
const DONE_SHOWN_MS = 1_500
const CLOSABLE_AFTER_MS = 20_000

const since = ref<number | null>(null)
const opened = ref(0)
const health = ref<Health | null>(null)
const unreachable = ref(false)
const now = ref(Date.now())

const progress = computed(() => (health.value && since.value ? wakeProgress(health.value.syncs, since.value) : null))
const heading = computed(() => {
  if (unreachable.value) return 'Echo is restarting'
  if (progress.value?.allDone) return 'All caught up'
  return 'Catching up after a pause'
})
const closable = computed(() => now.value - opened.value >= CLOSABLE_AFTER_MS || progress.value?.rows.some((r) => r.state === 'failed'))

const WORD: Record<WakeState, string> = { done: 'Up to date', failed: 'Failed', running: 'Syncing…', waiting: 'Waiting…' }
const TONE: Record<WakeState, string> = { done: 'text-ok', failed: 'text-bad', running: 'text-muted', waiting: 'text-faint' }

let poll: ReturnType<typeof setInterval> | undefined
let closing: ReturnType<typeof setTimeout> | undefined

function open(at: number) {
  if (since.value) return
  since.value = at
  opened.value = Date.now()
  poll = setInterval(check, POLL_MS)
  check()
}
function close() {
  clearInterval(poll)
  clearTimeout(closing)
  since.value = null
  health.value = null
  unreachable.value = false
}

async function load() {
  try {
    health.value = await request<Health>('GET', '/api/health')
    unreachable.value = false
  } catch {
    unreachable.value = true
  }
}
async function check() {
  await load()
  if (progress.value?.allDone && !unreachable.value && !closing) closing = setTimeout(close, DONE_SHOWN_MS)
}

let last = Date.now()
let tick: ReturnType<typeof setInterval> | undefined
onMounted(async () => {
  tick = setInterval(() => {
    now.value = Date.now()
    if (now.value - last > PAUSE_MS) open(now.value)
    last = now.value
  }, TICK_MS)

  // Opened just after Echo restarted itself, e.g. the page reloaded on wake.
  await load()
  const restarted = health.value?.scheduler.restartedAt ? Date.parse(health.value.scheduler.restartedAt) : 0
  if (Date.now() - restarted < RECENT_RESTART_MS && !wakeProgress(health.value!.syncs, restarted).allDone) open(restarted)
})
onBeforeUnmount(() => {
  clearInterval(tick)
  close()
})
</script>

<template>
  <div v-if="since" class="fixed inset-0 z-50 grid place-items-center bg-black/40 px-4" role="alertdialog" aria-modal="true" :aria-label="heading">
    <div class="grid w-full max-w-sm gap-4 rounded-xl border border-line bg-surface p-5 shadow-2xl">
      <div class="grid gap-1">
        <h2 class="flex items-center gap-2 text-base font-semibold">
          <span v-if="!progress?.allDone" class="size-3.5 animate-spin rounded-full border-2 border-accent border-t-transparent" aria-hidden="true" />
          {{ heading }}
        </h2>
        <p class="text-[13px] text-muted">
          {{ unreachable ? "It'll be back in a few seconds, then everything syncs again." : 'Echo is syncing again so what you see is current.' }}
        </p>
      </div>

      <ul v-if="progress && !unreachable" class="grid gap-2" aria-label="Syncs">
        <li v-for="row in progress.rows" :key="row.source" class="grid gap-0.5">
          <span class="flex items-center justify-between gap-3 text-[13px]">
            {{ row.label }}
            <span :class="['font-medium', TONE[row.state]]">{{ WORD[row.state] }}</span>
          </span>
          <span v-if="row.error" class="text-[12px] text-bad">{{ row.error }}</span>
        </li>
      </ul>

      <div v-if="closable && !progress?.allDone" class="flex items-center justify-between gap-3">
        <a href="/settings#health" class="text-[12.5px] font-medium text-accent hover:opacity-80">Open Health</a>
        <BaseButton @click="close">Continue anyway</BaseButton>
      </div>
    </div>
  </div>
</template>
