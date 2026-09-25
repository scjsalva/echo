<script setup lang="ts">
import { computed } from 'vue'
import BasePill from '@/components/ui/BasePill.vue'
import ListRow from '@/components/ui/ListRow.vue'
import SourceBadge from '@/components/ui/SourceBadge.vue'
import UserAvatar from '@/components/ui/UserAvatar.vue'
import { useDrawer } from '@/composables/useDrawer'
import { timeAgo } from '@/lib/format'
import { ci, reviewStatus } from '@/lib/labels'
import type { PullRequest } from '@/types/dashboard'

const props = defineProps<{ pr: PullRequest; now: number }>()

const { open } = useDrawer()
const review = computed(() => reviewStatus(props.pr))
</script>

<template>
  <ListRow @select="open({ type: 'pullRequest', key: pr.key })">
    <template #lead>
      <SourceBadge v-if="pr.mine">{{ pr.draft ? 'DRAFT' : 'PR' }}</SourceBadge>
      <UserAvatar v-else :name="pr.author" />
    </template>
    {{ pr.title }}
    <template #meta>
      <span>{{ pr.mine ? '' : `${pr.author} · ` }}{{ pr.repo }}#{{ pr.number }}</span>
      <BasePill v-if="pr.requestedFromMe" tone="accent">Requested from you</BasePill>
      <BasePill :tone="ci[pr.ci].tone">{{ ci[pr.ci].label }}</BasePill>
      <BasePill v-if="!pr.draft" :tone="review.tone">{{ review.label }}</BasePill>
      <span v-if="!pr.mine" class="font-mono"><span class="text-ok">+{{ pr.additions }}</span> <span class="text-bad">−{{ pr.deletions }}</span></span>
    </template>
    <template #aside>{{ timeAgo(pr.mine ? pr.updated : pr.opened, now) }}</template>
  </ListRow>
</template>
