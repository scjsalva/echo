<script setup lang="ts">
import { computed } from 'vue'
import { PhArrowSquareOut, PhGitDiff } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import DetailSection from '@/components/ui/DetailSection.vue'
import FactList from '@/components/ui/FactList.vue'
import MarkdownBlock from '@/components/ui/MarkdownBlock.vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import UserAvatar from '@/components/ui/UserAvatar.vue'
import NotificationContext from './NotificationContext.vue'
import PullRequestComments from './PullRequestComments.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { timeAgo } from '@/lib/format'
import { githubNotificationText } from '@/lib/githubNotifications'
import { ci, githubReason } from '@/lib/labels'
import type { PullRequest } from '@/types/dashboard'

const props = defineProps<{ pr: PullRequest; notificationId?: string }>()

const dashboard = useDashboard()
const { open } = useDrawer()

const notification = computed(() => dashboard.githubNotification(props.notificationId))
const ticket = computed(() => (props.pr.jiraKey ? dashboard.ticket(props.pr.jiraKey) : undefined))
const facts = computed(() => [
  { label: 'files', value: props.pr.changedFiles },
  { label: 'lines', value: `+${props.pr.additions} −${props.pr.deletions}` },
  { label: 'commits', value: props.pr.commits },
  { label: 'opened', value: `${timeAgo(props.pr.opened)} ago` },
])
const reviewTone = (state: string) => (state === 'approved' ? 'ok' : state === 'changes_requested' ? 'bad' : 'neutral')
</script>

<template>
  <SideDrawer :label="pr.title">
    <template #eyebrow>
      <span class="font-mono text-xs text-faint">{{ pr.repo }}#{{ pr.number }}</span>
      <BasePill v-if="pr.draft">Draft</BasePill>
      <BasePill :tone="ci[pr.ci].tone">{{ ci[pr.ci].label }}</BasePill>
    </template>
    <template #title>{{ pr.title }}</template>
    <template #actions>
      <BaseButton variant="primary" :href="pr.url">Open on GitHub <PhArrowSquareOut :size="14" /></BaseButton>
      <BaseButton :href="`/reviews/${pr.fullName ?? pr.key.split('#')[0]}/${pr.number}`" tooltip="Opens the diff to review it here, yourself or with Claude">
        <PhGitDiff :size="14" /> Review
      </BaseButton>
      <BaseButton v-if="ticket" @click="open({ type: 'ticket', key: ticket.key })">{{ ticket.key }}</BaseButton>
    </template>

    <NotificationContext
      v-if="notification"
      :label="githubReason[notification.reason].label"
      :actor="notification.actor"
      :at="notification.at"
      :text="githubNotificationText(notification, { withActor: false })"
      :href="pr.url"
      href-label="View on GitHub"
    />

    <DetailSection title="Description">
      <MarkdownBlock v-if="pr.description" :source="pr.description" />
      <p v-else class="text-[13px] text-faint">No description.</p>
    </DetailSection>

    <div class="flex flex-wrap items-center gap-x-5 gap-y-2">
      <span class="flex items-center gap-1.5 text-[13px]"><UserAvatar :name="pr.author" />{{ pr.author }}</span>
      <FactList :facts="facts" />
    </div>

    <DetailSection v-if="pr.reviews.length" title="Reviews">
      <ul>
        <li v-for="review in pr.reviews" :key="review.login" class="flex items-center gap-2 border-t border-line-soft py-1.5 text-[13px] first:border-t-0">
          <UserAvatar :name="review.login" />{{ review.login }}
          <BasePill class="ml-auto" :tone="reviewTone(review.state)">{{ review.state.replace('_', ' ') }}</BasePill>
        </li>
      </ul>
    </DetailSection>

    <PullRequestComments :repo="pr.fullName ?? pr.key.split('#')[0]" :number="pr.number" />
  </SideDrawer>
</template>
