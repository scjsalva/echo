<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { PhArrowSquareOut, PhPaperclip } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import CommentThread from '@/components/ui/CommentThread.vue'
import DetailSection from '@/components/ui/DetailSection.vue'
import FactList from '@/components/ui/FactList.vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import QuoteBlock from '@/components/ui/QuoteBlock.vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import NotificationContext from './NotificationContext.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { request } from '@/lib/api'
import { jiraKind, type Tone } from '@/lib/labels'
import type { JiraCategory, JiraRelatedTicket, JiraTicket, JiraTicketDetail } from '@/types/dashboard'

const props = defineProps<{ ticket: JiraTicket; notificationId?: string }>()

const dashboard = useDashboard()
const { open } = useDrawer()

const STATUS_TONE: Record<JiraCategory, Tone> = { todo: 'neutral', in_progress: 'warn', code_review: 'accent', post_development: 'ok', done: 'ok' }

const detail = ref<JiraTicketDetail | null>(null)
const loadError = ref<string | null>(null)

onMounted(async () => {
  try {
    detail.value = await request<JiraTicketDetail>('GET', `/api/jira/tickets/${props.ticket.key}`)
  } catch (error) {
    loadError.value = error instanceof Error ? error.message : "Couldn't load the full ticket"
  }
})

const notification = computed(() => dashboard.jiraNotification(props.notificationId))
const notificationText = computed(() => {
  const n = notification.value
  if (!n) return ''
  if (n.kind === 'assigned') return n.actor ? 'assigned it to you' : 'Assigned to you'
  if (n.kind === 'transition') return n.actor ? `moved it: ${n.body}` : `Status moved: ${n.body}`
  return `“${n.body}”`
})

const date = (iso: string | null | undefined) => (iso ? new Date(iso).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' }) : null)
const list = (items: string[] | undefined) => (items?.length ? items.join(', ') : null)

const facts = computed(() => {
  const d = detail.value
  const t = d?.timeTracking
  return [
    { label: 'Priority', value: props.ticket.priority },
    { label: 'Assignee', value: props.ticket.assignee },
    { label: 'Reporter', value: props.ticket.reporter },
    { label: 'Sprint', value: props.ticket.sprint },
    { label: 'Fix version', value: list(d?.fixVersions) },
    { label: 'Affects', value: list(d?.affectsVersions) },
    { label: 'Labels', value: list(d?.labels) },
    { label: 'Components', value: list(d?.components) },
    { label: 'Due', value: date(d?.due) },
    { label: 'Resolution', value: d?.resolution },
    { label: 'Estimate', value: t?.originalEstimate },
    { label: 'Remaining', value: t?.remainingEstimate },
    { label: 'Logged', value: t?.timeSpent },
    { label: 'Created', value: date(d?.created) },
    { label: 'Updated', value: date(d?.updated ?? props.ticket.updated) },
  ].filter((f): f is { label: string; value: string } => Boolean(f.value))
})

const related = computed(() => {
  const d = detail.value
  if (!d) return []
  return [
    ...(d.parent ? [{ ...d.parent, relation: 'parent' }] : []),
    ...d.subtasks.map((s) => ({ ...s, relation: 'subtask' })),
    ...d.links,
  ]
})

const pr = computed(() => (props.ticket.pr ? dashboard.pullRequest(props.ticket.pr) : undefined))

function openRelated(item: JiraRelatedTicket) {
  if (dashboard.ticket(item.key)) open({ type: 'ticket', key: item.key })
  else window.open(item.url, '_blank', 'noopener')
}

const fileSize = (bytes: number) => (bytes >= 1_048_576 ? `${(bytes / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`)
</script>

<template>
  <SideDrawer :label="ticket.key">
    <template #eyebrow>
      <span class="font-mono text-xs font-medium text-jira">{{ ticket.key }}</span>
      <BasePill>{{ ticket.type }}</BasePill>
      <BasePill :tone="STATUS_TONE[ticket.category]">{{ ticket.status }}</BasePill>
    </template>
    <template #title>{{ ticket.title }}</template>
    <template #actions>
      <BaseButton variant="primary" :href="ticket.url">Open in Jira <PhArrowSquareOut :size="14" /></BaseButton>
      <BaseButton v-if="pr" @click="open({ type: 'pullRequest', key: pr.key })">PR #{{ pr.number }}</BaseButton>
    </template>

    <NotificationContext
      v-if="notification"
      :label="jiraKind[notification.kind].label"
      :actor="notification.actor"
      :at="notification.at"
      :text="notificationText"
    />

    <p v-if="loadError" class="text-[13px] text-bad">{{ loadError }}</p>
    <p v-else-if="!detail" class="text-[13px] text-faint">Loading the full ticket…</p>

    <DetailSection title="Description">
      <QuoteBlock v-if="detail?.description ?? ticket.description">{{ detail?.description ?? ticket.description }}</QuoteBlock>
      <p v-else class="text-[13px] text-faint">No description.</p>
    </DetailSection>

    <section v-if="detail?.moreDetails.length">
      <h4 class="mb-2 flex items-center gap-1.5 text-[11px] font-medium tracking-[0.07em] text-faint uppercase">
        More details <InfoHint text="Your project's custom text fields, like acceptance criteria. The Atlassian CLI doesn't return their names, so they're shown in field order." />
      </h4>
      <div class="grid gap-3">
        <QuoteBlock v-for="(text, i) in detail.moreDetails" :key="i">{{ text }}</QuoteBlock>
      </div>
    </section>

    <DetailSection v-if="detail?.environment" title="Environment">
      <QuoteBlock>{{ detail.environment }}</QuoteBlock>
    </DetailSection>

    <FactList :facts="facts" />

    <DetailSection v-if="related.length" title="Related tickets">
      <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
        <li v-for="item in related" :key="`${item.relation}-${item.key}`">
          <button type="button" class="grid w-full gap-0.5 px-3 py-2 text-left hover:bg-subtle" @click="openRelated(item)">
            <span class="text-[11px] text-faint">{{ item.relation }}</span>
            <span class="text-[13px]"><span class="font-mono text-xs font-medium text-jira">{{ item.key }}</span> {{ item.title }}</span>
            <span v-if="item.status" class="text-xs text-muted">{{ item.status }}</span>
          </button>
        </li>
      </ul>
    </DetailSection>

    <DetailSection v-if="detail?.attachments.length" :title="`Attachments · ${detail.attachments.length}`">
      <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
        <li v-for="file in detail.attachments" :key="`${file.name}-${file.created}`">
          <a :href="ticket.url" target="_blank" rel="noopener" class="flex items-center gap-2 px-3 py-2 text-[13px] hover:bg-subtle">
            <PhPaperclip :size="14" class="shrink-0 text-faint" />
            <span class="min-w-0 flex-1 break-words">{{ file.name }}</span>
            <span class="shrink-0 text-xs text-faint">{{ fileSize(file.size) }}</span>
            <PhArrowSquareOut :size="12" class="shrink-0 text-faint" />
          </a>
        </li>
      </ul>
    </DetailSection>

    <DetailSection v-if="detail" :title="`Comments · ${detail.comments.length}`">
      <p v-if="!detail.comments.length" class="text-[13px] text-faint">No comments yet.</p>
      <ol v-else class="grid gap-3">
        <li v-for="c in detail.comments" :key="c.id">
          <CommentThread :author="c.author" :bot="c.bot" :at="c.created" :body="c.text ?? ''" />
        </li>
      </ol>
    </DetailSection>
  </SideDrawer>
</template>
