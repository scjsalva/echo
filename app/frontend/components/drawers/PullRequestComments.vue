<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { PhFileCode } from '@phosphor-icons/vue'
import CommentThread from '@/components/ui/CommentThread.vue'
import DetailSection from '@/components/ui/DetailSection.vue'
import { request } from '@/lib/api'
import type { PullRequestComment } from '@/types/dashboard'
import type { Tone } from '@/lib/labels'

const props = defineProps<{ repo: string; number: number }>()

const comments = ref<PullRequestComment[] | null>(null)
const loadError = ref<string | null>(null)

onMounted(async () => {
  try {
    comments.value = (await request<{ comments: PullRequestComment[] }>('GET', `/api/github/pull_requests/${props.repo}/${props.number}/comments`)).comments
  } catch (error) {
    loadError.value = error instanceof Error ? error.message : "Couldn't load the comments"
  }
})

const REVIEW: Record<string, { label: string; tone: Tone }> = {
  approved: { label: 'Approved', tone: 'ok' },
  changes_requested: { label: 'Changes requested', tone: 'bad' },
  commented: { label: 'Reviewed', tone: 'neutral' },
  dismissed: { label: 'Dismissed', tone: 'neutral' },
}

const pillFor = (c: PullRequestComment) => (c.kind === 'review' && c.state ? (REVIEW[c.state] ?? { label: c.state, tone: 'neutral' as Tone }) : undefined)

type Thread = { key: string; root: PullRequestComment; replies: PullRequestComment[] }
type Item = { at: string; single: PullRequestComment } | { at: string; thread: Thread }

// Line comments reply to the thread's root, not necessarily their immediate parent,
// so grouping by that id gathers a whole thread in one pass.
const items = computed<Item[]>(() => {
  const all = comments.value
  if (!all) return []

  const lineComments = all.filter((c) => c.kind === 'line')
  const byId = new Map(lineComments.map((c) => [c.id, c]))
  const roots = lineComments.filter((c) => !c.replyTo || !byId.has(c.replyTo))
  const repliesByRoot = new Map<string, PullRequestComment[]>()
  for (const c of lineComments) {
    if (c.replyTo && byId.has(c.replyTo)) repliesByRoot.set(c.replyTo, [...(repliesByRoot.get(c.replyTo) ?? []), c])
  }

  const threads: Item[] = roots.map((root) => ({
    at: root.at,
    thread: { key: root.id, root, replies: (repliesByRoot.get(root.id) ?? []).sort((a, b) => a.at.localeCompare(b.at)) },
  }))
  const singles: Item[] = all.filter((c) => c.kind !== 'line').map((c) => ({ at: c.at, single: c }))

  return [...threads, ...singles].sort((a, b) => a.at.localeCompare(b.at))
})
</script>

<template>
  <DetailSection :title="comments ? `Comments · ${comments.length}` : 'Comments'">
    <p v-if="loadError" class="text-[13px] text-bad">Couldn't load the comments: {{ loadError }}</p>
    <p v-else-if="!comments" class="text-[13px] text-faint">Loading comments…</p>
    <p v-else-if="!comments.length" class="text-[13px] text-faint">No comments yet.</p>
    <ol v-else class="grid gap-4">
      <li v-for="item in items" :key="'thread' in item ? item.thread.key : item.single.id" class="grid min-w-0 gap-1.5">
        <template v-if="'thread' in item">
          <span class="flex items-center gap-1 font-mono text-[11.5px] break-all text-muted">
            <PhFileCode :size="13" class="shrink-0" />{{ item.thread.root.path }}<template v-if="item.thread.root.line">:{{ item.thread.root.line }}</template>
          </span>
          <div class="grid gap-2">
            <CommentThread
              :author="item.thread.root.author"
              :bot="item.thread.root.bot"
              :at="item.thread.root.at"
              :url="item.thread.root.url"
              :body="item.thread.root.body"
              markdown
            />
            <CommentThread
              v-for="reply in item.thread.replies"
              :key="reply.id"
              nested
              :author="reply.author"
              :bot="reply.bot"
              :at="reply.at"
              :url="reply.url"
              :body="reply.body"
              markdown
            />
          </div>
        </template>
        <CommentThread
          v-else
          :author="item.single.author"
          :bot="item.single.bot"
          :at="item.single.at"
          :url="item.single.url"
          :body="item.single.body"
          :pill="pillFor(item.single)"
          markdown
        />
      </li>
    </ol>
  </DetailSection>
</template>
