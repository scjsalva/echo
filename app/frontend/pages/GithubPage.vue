<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { PhMagnifyingGlass } from '@phosphor-icons/vue'
import PullRequestRow from '@/components/dashboard/PullRequestRow.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import AppShell from '@/components/layout/AppShell.vue'
import FilterChips from '@/components/ui/FilterChips.vue'
import FilterMenu, { type FilterGroup } from '@/components/ui/FilterMenu.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { useDeepLink } from '@/composables/useDeepLink'
import { useUrlList, useUrlParam } from '@/composables/useUrlState'
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
  // `filter` is what older links used; today's filters are read straight from the address bar below.
  const legacy = params.get('filter')
  if (legacy === 'team') tab.value = 'team'
  if (legacy === 'requested') lists.review.value = [...lists.review.value, 'requested']
  const key = params.get('pr')
  const notificationId = params.get('notification') ?? undefined
  if (notificationId) dashboard.markRead(notificationId)
  if (key) open({ type: 'pullRequest', key, notificationId })
})

type Tab = 'all' | 'team' | 'mine'

// The tab, filters and search live in the address bar (e.g. ?tab=team&status=ready, the
// dashboard's review queue), so a reload, a bookmark or a shared link shows the same list.
const tab = useUrlParam<Tab>('tab', 'all', ['all', 'team', 'mine'])
const lists = { status: useUrlList('status'), review: useUrlList('review'), author: useUrlList('author'), repo: useUrlList('repo') }
const filters = computed<Record<string, string[]>>({
  get: () => ({ status: lists.status.value, review: lists.review.value, author: lists.author.value, repo: lists.repo.value }),
  set: (value) => (Object.keys(lists) as (keyof typeof lists)[]).forEach((key) => (lists[key].value = value[key] ?? [])),
})
const query = useUrlParam('q', '')

const newestFirst = (prs: PullRequest[]) => [...prs].sort((a, b) => Date.parse(b.opened) - Date.parse(a.opened))
// All: every open PR in the repos you watch, yours too. Team: your team's, not yours. Mine: yours, in any repo.
const all = computed(() => newestFirst((data.value.pullRequests ?? []).filter((pr) => pr.fullName && data.value.repos.includes(pr.fullName))))
const team = computed(() => all.value.filter((pr) => !pr.mine && data.value.team.includes(pr.author)))
const mine = computed(() => newestFirst((data.value.pullRequests ?? []).filter((pr) => pr.mine)))
const base = computed(() => ({ all: all.value, team: team.value, mine: mine.value })[tab.value])

const tabs = computed(() => [
  { value: 'all' as const, label: 'All', count: all.value.length },
  { value: 'team' as const, label: 'Team', count: team.value.length },
  { value: 'mine' as const, label: 'My PRs', count: mine.value.length },
])

const STATUS: Record<string, (pr: PullRequest) => boolean> = { ready: (pr) => !pr.draft, draft: (pr) => pr.draft }
const REVIEW: Record<string, (pr: PullRequest) => boolean> = {
  review_required: (pr) => pr.reviewState === 'review_required',
  approved: (pr) => pr.reviewState === 'approved',
  changes_requested: (pr) => pr.reviewState === 'changes_requested',
  requested: (pr) => pr.requestedFromMe,
}
const count = (test: (pr: PullRequest) => boolean) => base.value.filter(test).length
const groups = computed<FilterGroup[]>(() => {
  const tally = (key: (pr: PullRequest) => string | undefined) => {
    const counts = new Map<string, number>()
    for (const pr of base.value) {
      const value = key(pr)
      if (value) counts.set(value, (counts.get(value) ?? 0) + 1)
    }
    return [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
  }
  return [
    { key: 'status', label: 'Status', options: [
      { value: 'ready', label: 'Ready for review', count: count(STATUS.ready) },
      { value: 'draft', label: 'Draft', count: count(STATUS.draft) },
    ] },
    { key: 'review', label: 'Reviews', options: [
      { value: 'review_required', label: 'Review required', count: count(REVIEW.review_required) },
      { value: 'approved', label: 'Approved', count: count(REVIEW.approved) },
      { value: 'changes_requested', label: 'Changes requested', count: count(REVIEW.changes_requested) },
      { value: 'requested', label: 'Requested from me', count: count(REVIEW.requested) },
    ] },
    { key: 'author', label: 'Author', options: tally((pr) => pr.author).map(([value, n]) => ({ value, label: value, count: n })) },
    { key: 'repo', label: 'Repo', options: tally((pr) => pr.fullName).map(([value, n]) => ({ value, label: value.split('/').pop()!, count: n })) },
  ]
})

// Within a group any choice matches; across groups all must.
const passes = (pr: PullRequest) =>
  (!filters.value.status.length || filters.value.status.some((s) => STATUS[s]?.(pr))) &&
  (!filters.value.review.length || filters.value.review.some((r) => REVIEW[r]?.(pr))) &&
  (!filters.value.author.length || filters.value.author.includes(pr.author)) &&
  (!filters.value.repo.length || (pr.fullName !== undefined && filters.value.repo.includes(pr.fullName)))
const matches = (pr: PullRequest) => {
  const q = query.value.trim().toLowerCase()
  return !q || `${pr.repo}#${pr.number} ${pr.title} ${pr.author}`.toLowerCase().includes(q)
}

const PAGE = 20

// Everything here is already synced, so Load more just shows more of it. Syncs
// and refreshes keep what's shown; changing tab, filters or search starts over.
const shown = ref(PAGE)
watch([tab, filters, query], () => (shown.value = PAGE), { deep: true })

const visible = computed(() => base.value.filter((pr) => passes(pr) && matches(pr)))
const TITLES: Record<Tab, string> = { all: 'All open pull requests', team: "Your team's pull requests", mine: 'My pull requests' }
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
      <div class="relative flex flex-wrap items-center gap-3">
        <FilterChips v-model="tab" :options="tabs" label="Pull requests" />
        <FilterMenu v-model="filters" :groups="groups" />
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

      <section>
        <SectionHeader
          :title="TITLES[tab]"
          :meta="tab === 'mine' ? 'Newest first' : `${data.repos.length} watched repos · newest first`"
          href="/settings#github"
          link-label="Choose repos and team"
        />
        <p v-if="!visible.length" class="rounded-[10px] border border-line bg-surface px-4 py-6 text-center text-[13px] text-faint">
          {{ tab === 'team' && !data.team.length ? 'Add your team in Settings to see their pull requests here.' : query || visible.length < base.length ? 'No pull requests match.' : 'Nothing here.' }}
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
