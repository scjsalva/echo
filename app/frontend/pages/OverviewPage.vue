<script setup lang="ts">
import AppShell from '@/components/layout/AppShell.vue'
import AgentsSection from '@/components/dashboard/AgentsSection.vue'
import GithubSection from '@/components/dashboard/GithubSection.vue'
import JiraSection from '@/components/dashboard/JiraSection.vue'
import ReviewQueue from '@/components/dashboard/ReviewQueue.vue'
import StatsStrip from '@/components/dashboard/StatsStrip.vue'
import WaitingList from '@/components/dashboard/WaitingList.vue'
import DrawerHost from '@/components/drawers/DrawerHost.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer } from '@/composables/useDrawer'
import type { OverviewProps } from '@/types/dashboard'

const props = defineProps<OverviewProps>()

const { data, refreshFailed } = provideDashboard(props)
provideDrawer()
</script>

<template>
  <AppShell :shell="data.shell" :refresh-failed="refreshFailed">
    <div class="grid items-start gap-7 lg:grid-cols-[minmax(0,1fr)_320px]">
      <main class="grid min-w-0 gap-7">
        <StatsStrip :stats="data.stats" />
        <WaitingList v-if="data.waiting.total" :items="data.waiting.items" :total="data.waiting.total" />
        <ReviewQueue :items="data.reviewQueue.items" :total="data.reviewQueue.total" />
      </main>
      <aside class="grid min-w-0 gap-3" aria-label="Agents, GitHub and Jira">
        <AgentsSection :agents="data.agents" />
        <GithubSection :pull-requests="data.pullRequests" :notifications="data.githubNotifications" />
        <JiraSection :tickets="data.jiraTickets" :notifications="data.jiraNotifications" />
      </aside>
    </div>
    <DrawerHost />
  </AppShell>
</template>
