<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhChecks } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import GithubNotificationRow from '@/components/inbox/GithubNotificationRow.vue'
import JiraNotificationRow from '@/components/inbox/JiraNotificationRow.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import ListRow from '@/components/ui/ListRow.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import { sourceBadge, waitingSummary } from '@/lib/waiting'
import type { Connection, OverviewProps, WaitingItem } from '@/types/dashboard'

const props = defineProps<Omit<OverviewProps, 'stats' | 'reviewQueue'> & { connections: Connection[] }>()

const { data, refreshFailed, markAllRead } = provideDashboard(props, '/api/notifications')
const { open } = provideDrawer()
const now = useNow(30_000)

type Tab = 'waiting' | 'all' | 'jira' | 'github'
const tab = ref<Tab>('all')
useDeepLink((params) => {
  const linked = params.get('tab')
  if (linked === 'waiting' || linked === 'jira' || linked === 'github') tab.value = linked
})
const status = ref<WaitingItem['status']>('open')
const unreadOnly = ref(false)

const waiting = computed(() => data.value.waiting?.items ?? [])
const jira = computed(() => data.value.jiraNotifications ?? [])
const github = computed(() => data.value.githubNotifications ?? [])
const unreadIn = (list: { unread: boolean }[]) => list.filter((n) => n.unread).length
const unread = computed(() => unreadIn(jira.value) + unreadIn(github.value))
const connected = (key: Connection['key']) => props.connections.find((c) => c.key === key)?.connected

const tabs = computed(() => [
  { value: 'waiting' as const, label: 'Waiting on you', count: waiting.value.filter((w) => w.status === 'open').length },
  { value: 'all' as const, label: 'All', count: unread.value },
  { value: 'jira' as const, label: 'Jira', count: unreadIn(jira.value) },
  { value: 'github' as const, label: 'GitHub', count: unreadIn(github.value) },
])
const statuses = computed(() =>
  (['open', 'resolved', 'dismissed'] as const).map((value) => ({
    value,
    label: { open: 'Open', resolved: 'Resolved', dismissed: 'Dismissed' }[value],
    count: waiting.value.filter((w) => w.status === value).length,
  })),
)
const waitingItems = computed(() => waiting.value.filter((w) => w.status === status.value))
// One feed, newest first, tagged by source so each row renders its own way.
const notifications = computed(() =>
  [
    ...(tab.value !== 'github' ? jira.value.map((n) => ({ source: 'jira' as const, n })) : []),
    ...(tab.value !== 'jira' ? github.value.map((n) => ({ source: 'github' as const, n })) : []),
  ]
    .filter(({ n }) => !unreadOnly.value || n.unread)
    .sort((a, b) => Date.parse(b.n.at) - Date.parse(a.n.at)),
)
</script>

<template>
  <AppShell :shell="data.shell" title="Notifications" :refresh-failed="refreshFailed" :show-first-run="false">
    <div class="grid gap-4">
      <FilterChips v-model="tab" :options="tabs" label="Notification source" />

      <template v-if="tab === 'waiting'">
        <FilterChips v-model="status" :options="statuses" label="Waiting status" />
        <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
          <p v-if="!waitingItems.length" class="px-4 py-6 text-center text-[13px] text-faint">Nothing here.</p>
          <ListRow v-for="item in waitingItems" :key="item.key" @select="open({ type: 'waiting', key: item.key })">
            <template #lead>
              <SourceBadge :tone="item.source === 'jira' ? 'jira' : 'default'">{{ sourceBadge[item.source] }}</SourceBadge>
            </template>
            {{ item.kind === 'agent_blocked' ? item.title : `${item.label} · ${item.title}` }}
            <template #content>{{ waitingSummary(item) }}</template>
            <template v-if="item.status !== 'open'" #meta>
              <BasePill :tone="item.status === 'resolved' ? 'ok' : 'neutral'">{{ item.resolution ?? 'Dismissed' }}</BasePill>
            </template>
            <template #aside>{{ timeAgo(item.at, now) }}</template>
          </ListRow>
        </div>
      </template>

      <template v-else-if="tab === 'github' && !connected('github')">
        <div class="grid max-w-xl gap-2 rounded-xl border border-dashed border-line px-6 py-8">
          <h2 class="text-base font-semibold">GitHub isn't connected yet</h2>
          <p class="text-muted">Its notifications will show here once it is.</p>
        </div>
      </template>

      <template v-else>
        <div class="flex flex-wrap items-center gap-3">
          <FilterChips
            :model-value="unreadOnly ? 'unread' : 'everything'"
            :options="[{ value: 'everything', label: 'Everything' }, { value: 'unread', label: 'Unread only', count: tab === 'all' ? unread : unreadIn(tab === 'jira' ? jira : github) }]"
            label="Read state"
            @update:model-value="unreadOnly = $event === 'unread'"
          />
          <BaseButton v-if="unread" class="ml-auto" size="sm" @click="markAllRead"><PhChecks :size="13" /> Mark all read</BaseButton>
        </div>
        <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
          <p v-if="!notifications.length" class="px-4 py-6 text-center text-[13px] text-faint">
            {{ unreadOnly ? 'All caught up.' : 'No notifications in the last 14 days.' }}
          </p>
          <template v-for="item in notifications" :key="`${item.source}-${item.n.id}`">
            <JiraNotificationRow v-if="item.source === 'jira'" :notification="item.n" :now="now" />
            <GithubNotificationRow v-else :notification="item.n" :now="now" />
          </template>
        </div>
      </template>
    </div>
    <DrawerHost />
  </AppShell>
</template>
