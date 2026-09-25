<script setup lang="ts">
import { computed } from 'vue'
import CollapsibleSection from '@/components/ui/CollapsibleSection.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import UserAvatar from '@/components/ui/UserAvatar.vue'
import MiniRow from './MiniRow.vue'
import SideEmpty from './SideEmpty.vue'
import SideGroupLabel from './SideGroupLabel.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { usePersistentFlag } from '@/composables/usePersistentFlag'
import { githubNotificationText } from '@/lib/githubNotifications'
import { ci, githubReason, reviewStatus } from '@/lib/labels'
import type { GithubNotification, PullRequest } from '@/types/dashboard'

const props = defineProps<{ pullRequests: PullRequest[]; notifications: GithubNotification[] }>()

const { open } = useDrawer()
const { markRead } = useDashboard()
const expanded = usePersistentFlag('overview.github', true)

const mine = computed(() => props.pullRequests.filter((pr) => pr.mine))
const unread = computed(() => props.notifications.filter((n) => n.unread))
const titleOf = (key: string) => props.pullRequests.find((pr) => pr.key === key)?.title ?? props.notifications.find((n) => n.prKey === key)?.title ?? key
</script>

<template>
  <CollapsibleSection v-model:open="expanded" title="GitHub" :summary="`${mine.length} PRs · ${unread.length} unread`">
    <SideGroupLabel>My PRs</SideGroupLabel>
    <SideEmpty v-if="!mine.length">No open PRs.</SideEmpty>
    <MiniRow v-for="pr in mine" :key="pr.key" @select="open({ type: 'pullRequest', key: pr.key })">
      <template #lead><SourceBadge>{{ pr.draft ? 'DRAFT' : 'PR' }}</SourceBadge></template>
      {{ pr.title }}
      <template #sub>{{ reviewStatus(pr).label }} · {{ ci[pr.ci].label }}</template>
    </MiniRow>

    <template v-if="unread.length">
      <SideGroupLabel>Unread</SideGroupLabel>
      <MiniRow
        v-for="n in unread"
        :key="n.id"
        @select="markRead(n.id); open({ type: 'pullRequest', key: n.prKey, notificationId: n.id })"
      >
        <template #lead>
          <UserAvatar v-if="n.actor" :name="n.actor" />
          <SourceBadge v-else>GH</SourceBadge>
        </template>
        {{ githubReason[n.reason]?.label ?? 'Activity' }}
        <template #sub>{{ githubNotificationText(n) }} · {{ titleOf(n.prKey) }}</template>
      </MiniRow>
    </template>

    <div class="mt-2.5 flex flex-wrap gap-x-4 text-[12.5px] font-medium text-accent">
      <a href="/github" class="hover:opacity-80">All GitHub →</a>
      <a href="/inbox" class="hover:opacity-80">Notifications →</a>
    </div>
  </CollapsibleSection>
</template>
