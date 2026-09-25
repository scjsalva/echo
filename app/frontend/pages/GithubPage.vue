<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { PhFunnel, PhMagnifyingGlass } from '@phosphor-icons/vue'
import PullRequestRow from '@/components/dashboard/PullRequestRow.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import AppShell from '@/components/layout/AppShell.vue'
import BaseTooltip from '@/components/ui/BaseTooltip.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { provideDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import type { GithubPageProps, PullRequest } from '@/types/dashboard'

const props = defineProps<GithubPageProps>()

const dashboard = provideDashboard(props, '/api/github/pull_requests')
const { data, refreshFailed } = dashboard
const { open } = provideDrawer()
const now = useNow(30_000)

useDeepLink((params) => {
  // From the Overview stats, e.g. /github?tab=mine or /github?filter=team.
  if (params.get('tab') === 'mine') tab.value = 'mine'
  const filter = params.get('filter')
  if (filter === 'team' || filter === 'requested') queueFilter.value = filter
  const key = params.get('pr')
  const notificationId = params.get('notification') ?? undefined
  if (notificationId) dashboard.markRead(notificationId)
  if (key && dashboard.pullRequest(key)) open({ type: 'pullRequest', key, notificationId })
  else if (notificationId) {
    const url = dashboard.githubNotification(notificationId)?.url
    if (url) window.open(url, '_blank', 'noopener')
  }
})

type Tab = 'queue' | 'mine'
type QueueFilter = 'all' | 'requested' | 'team'
type MineFilter = 'open' | 'drafts' | 'all'

const tab = ref<Tab>('queue')
const queueFilter = ref<QueueFilter>('all')
const mineFilter = ref<MineFilter>('open')
const repo = ref('all')
const showRepos = ref(false)
const query = ref('')

const queue = computed(() => data.value.reviewQueue ?? [])
const mine = computed(() =>
  (data.value.pullRequests ?? []).filter((pr) => pr.mine).sort((a, b) => Date.parse(b.opened) - Date.parse(a.opened)),
)
const onTeam = (pr: PullRequest) => data.value.team.includes(pr.author)
const matches = (pr: PullRequest) => {
  const q = query.value.trim().toLowerCase()
  return (repo.value === 'all' || pr.fullName === repo.value) && (!q || `${pr.repo}#${pr.number} ${pr.title} ${pr.author}`.toLowerCase().includes(q))
}

const tabs = computed(() => [
  { value: 'queue' as const, label: 'Review queue', count: queue.value.length },
  { value: 'mine' as const, label: 'My PRs', count: mine.value.length },
])
const queueFilters = computed(() => [
  { value: 'all' as const, label: 'All ready', count: queue.value.length },
  { value: 'requested' as const, label: 'Requested from me', count: queue.value.filter((pr) => pr.requestedFromMe).length },
  { value: 'team' as const, label: 'My team', count: queue.value.filter(onTeam).length },
])
const mineFilters = computed(() => [
  { value: 'open' as const, label: 'Open', count: mine.value.filter((pr) => !pr.draft).length },
  { value: 'drafts' as const, label: 'Drafts', count: mine.value.filter((pr) => pr.draft).length },
  { value: 'all' as const, label: 'All', count: mine.value.length },
])
const repos = computed(() => {
  const source = tab.value === 'queue' ? queue.value : mine.value
  const counts = new Map<string, number>()
  for (const pr of source) if (pr.fullName) counts.set(pr.fullName, (counts.get(pr.fullName) ?? 0) + 1)
  return [
    { value: 'all', label: 'All repos', count: source.length },
    ...[...counts.entries()].sort((a, b) => b[1] - a[1]).map(([value, count]) => ({ value, label: value.split('/').pop()!, count })),
  ]
})

const PAGE = 20

// Everything here is already synced, so Load more just shows more of it. Syncs
// and refreshes keep what's shown; changing tab, filters or search starts over.
const shown = ref(PAGE)
watch([tab, queueFilter, mineFilter, repo, query], () => (shown.value = PAGE))

const visible = computed(() => {
  if (tab.value === 'queue') {
    return queue.value.filter(
      (pr) => (queueFilter.value === 'all' || (queueFilter.value === 'requested' ? pr.requestedFromMe : onTeam(pr))) && matches(pr),
    )
  }
  return mine.value.filter((pr) => (mineFilter.value === 'all' || (mineFilter.value === 'drafts') === pr.draft) && matches(pr))
})
</script>

<template>
  <AppShell :shell="data.shell" title="GitHub" :refresh-failed="refreshFailed" :show-first-run="false">
    <div v-if="!connected" class="grid max-w-xl gap-2 rounded-xl border border-dashed border-line px-6 py-10">
      <h2 class="text-base font-semibold">GitHub isn't connected</h2>
      <p class="text-muted">
        Log in through the GitHub CLI to see your PRs and review queue here.
        <a href="/settings#connections" class="font-medium text-accent hover:opacity-80">Set up GitHub →</a>
      </p>
    </div>

    <div v-else class="grid gap-5">
      <div class="flex flex-wrap items-center gap-3">
        <FilterChips v-model="tab" :options="tabs" label="Pull requests" />
        <label class="relative ml-auto">
          <PhMagnifyingGlass :size="14" class="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-faint" />
          <input
            v-model="query"
            type="search"
            placeholder="Search title, number or author"
            aria-label="Search pull requests"
            class="w-72 rounded-md border border-line bg-surface py-1.5 pr-3 pl-8 text-[13px] placeholder:text-faint"
          />
        </label>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <FilterChips v-if="tab === 'queue'" v-model="queueFilter" :options="queueFilters" label="Review queue filter" />
        <FilterChips v-else v-model="mineFilter" :options="mineFilters" label="My PRs filter" />
        <BaseTooltip :text="showRepos ? 'Hide repo filter' : 'Filter by repo'">
          <button
            type="button"
            :aria-pressed="showRepos"
            aria-label="Filter by repo"
            :class="[
              'rounded-full border p-1.5',
              showRepos || repo !== 'all' ? 'border-transparent bg-accent-soft text-accent' : 'border-line bg-surface text-muted hover:text-ink',
            ]"
            @click="showRepos = !showRepos"
          >
            <PhFunnel :size="14" :weight="repo !== 'all' ? 'fill' : 'regular'" />
          </button>
        </BaseTooltip>
      </div>
      <FilterChips v-if="showRepos" v-model="repo" :options="repos" label="Filter by repo" />

      <section>
        <SectionHeader
          :title="tab === 'queue' ? 'Ready for review' : 'My pull requests'"
          :meta="tab === 'queue' ? `${data.repos.length} watched repos · newest first` : 'Newest first'"
          href="/settings#github"
          link-label="Choose repos and team"
        />
        <p v-if="!visible.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">
          {{ query ? 'No pull requests match your search.' : tab === 'queue' && queueFilter === 'team' && !data.team.length ? 'Add your team in Settings to use this filter.' : 'Nothing here.' }}
        </p>
        <template v-else>
          <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
            <PullRequestRow v-for="pr in visible.slice(0, shown)" :key="pr.key" :pr="pr" :now="now" />
          </div>
          <div v-if="shown < visible.length" class="flex justify-center py-3">
            <BaseButton size="sm" @click="shown += PAGE">Load more</BaseButton>
          </div>
        </template>
      </section>

      <p v-if="syncedAt" class="text-[12.5px] text-faint">Synced from GitHub {{ timeAgo(syncedAt, now) }} ago. Echo checks for changes every minute.</p>
    </div>
    <DrawerHost />
  </AppShell>
</template>
