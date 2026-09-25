<script setup lang="ts">
import ListRow from '@/components/ui/ListRow.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import { useDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import { sourceBadge, waitingSummary } from '@/lib/waiting'
import type { WaitingItem } from '@/types/dashboard'

defineProps<{ items: WaitingItem[]; total: number }>()

const { open } = useDrawer()
const now = useNow(30_000)
</script>

<template>
  <section aria-labelledby="waiting-heading" class="overflow-hidden rounded-xl border border-warn/35 bg-surface">
    <header class="flex items-center gap-2 bg-warn-soft px-4 py-3 text-warn">
      <span class="size-2 rounded-full bg-warn ring-3 ring-warn/20" aria-hidden="true" />
      <h2 id="waiting-heading" class="text-base font-semibold tracking-tight">Waiting on you</h2>
      <span class="font-mono text-xs opacity-80">{{ total }}</span>
      <a href="/inbox" class="ml-auto text-[12.5px] font-medium hover:opacity-80">See all →</a>
    </header>

    <p v-if="!items.length" class="px-4 py-5 text-[13px] text-faint">Nothing is waiting on you.</p>
    <div class="border-t border-line-soft">
      <ListRow v-for="item in items" :key="item.key" @select="open({ type: 'waiting', key: item.key })">
        <template #lead>
          <SourceBadge :tone="item.source === 'jira' ? 'jira' : 'default'">{{ sourceBadge[item.source] }}</SourceBadge>
        </template>
        {{ item.kind === 'agent_blocked' ? item.title : `${item.label} · ${item.title}` }}
        <template #content>{{ waitingSummary(item) }}</template>
        <template #aside>{{ timeAgo(item.at, now) }}</template>
      </ListRow>
    </div>
  </section>
</template>
