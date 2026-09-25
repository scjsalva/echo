<script setup lang="ts">
import { PhX } from '@phosphor-icons/vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import { useAlerts } from '@/composables/useAlerts'

const { alerts, dismiss } = useAlerts()

const BADGE: Record<string, string> = { agent: 'CC', github: 'GH', jira: 'JIRA' }

// Stay on the Echo you're looking at, even if the link was made for another port.
const path = (url?: string) => (url ? `${new URL(url).pathname}${new URL(url).search}` : '/inbox')
</script>

<template>
  <div class="pointer-events-none fixed top-4 right-4 z-40 grid w-[min(360px,calc(100vw-2rem))] gap-2" aria-live="polite">
    <div
      v-for="alert in alerts"
      :key="alert.id"
      role="status"
      class="pointer-events-auto grid grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-3 rounded-xl border border-warn/40 bg-surface px-3.5 py-3 shadow-xl"
    >
      <SourceBadge :tone="alert.source === 'jira' ? 'jira' : 'default'">{{ BADGE[alert.source] ?? 'ECHO' }}</SourceBadge>
      <a :href="path(alert.url)" class="grid min-w-0 gap-0.5 hover:opacity-80">
        <span class="text-[13px] font-semibold">{{ alert.title }}<template v-if="alert.subtitle"> · {{ alert.subtitle }}</template></span>
        <span class="line-clamp-2 text-[12.5px] break-words text-muted">{{ alert.message }}</span>
      </a>
      <button type="button" class="rounded-md p-0.5 text-faint hover:bg-subtle hover:text-ink" aria-label="Dismiss" @click="dismiss(alert.id)">
        <PhX :size="14" />
      </button>
    </div>
  </div>
</template>
