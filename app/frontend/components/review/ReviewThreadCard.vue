<script setup lang="ts">
import { computed, inject, ref } from 'vue'
import { PhArrowBendUpLeft, PhArrowSquareOut, PhCaretRight, PhChatsCircle, PhCheckCircle } from '@phosphor-icons/vue'
import CommentThread from '@/components/ui/CommentThread.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import CommentComposer from './CommentComposer.vue'
import ReviewCommentCard from './ReviewCommentCard.vue'
import type { ThreadActions } from '@/composables/useReview'
import type { ReviewThread } from '@/types/dashboard'

const props = defineProps<{ thread: ReviewThread }>()
const actions = inject<ThreadActions | null>('threadActions', null)
const repo = inject<{ value: string | undefined } | undefined>('reviewRepo', undefined)

// Folded to one line by default, so a busy PR stays readable; your own reply keeps it open.
const replies = computed(() => actions?.replies(props.thread) ?? [])
const expanded = ref(replies.value.length > 0)
const composing = ref(false)
const resolving = ref(false)

function startReply() {
  expanded.value = true
  composing.value = true
}

async function setResolved(resolved: boolean) {
  resolving.value = true
  await actions?.setResolved(props.thread, resolved)
  resolving.value = false
}
</script>

<template>
  <article
    :class="['grid gap-2 rounded-lg border bg-surface px-3 py-2.5 font-sans shadow-sm', thread.resolved ? 'border-line opacity-80' : 'border-warn/40']"
    :aria-label="thread.resolved ? 'Resolved thread' : 'Unresolved thread'"
  >
    <header class="flex flex-wrap items-center gap-2 text-[12.5px]">
      <button type="button" class="inline-flex flex-wrap items-center gap-1.5 text-left hover:opacity-80" :aria-expanded="expanded" @click="expanded = !expanded">
        <PhCaretRight :size="11" weight="bold" :class="['text-faint transition-transform', expanded && 'rotate-90']" />
        <span v-if="thread.resolved" class="inline-flex items-center gap-1 font-medium text-ok"><PhCheckCircle :size="14" weight="fill" /> Resolved on GitHub</span>
        <span v-else class="inline-flex items-center gap-1 font-medium text-warn"><PhChatsCircle :size="14" weight="fill" /> Unresolved on GitHub</span>
        <span class="text-muted">· {{ thread.comments[0]?.author ?? 'Someone' }} · {{ thread.comments.length }} comment{{ thread.comments.length === 1 ? '' : 's' }}</span>
      </button>
      <span v-if="thread.outdated && thread.originalLine" class="text-faint">was line {{ thread.originalLine }}</span>
      <a v-if="thread.comments[0]?.url" :href="thread.comments[0].url" target="_blank" rel="noopener" class="ml-auto inline-flex items-center gap-1 text-faint hover:text-ink">
        On GitHub <PhArrowSquareOut :size="12" />
      </a>
    </header>
    <template v-if="expanded">
      <CommentThread
        v-for="(comment, i) in thread.comments"
        :key="comment.id"
        :author="comment.author"
        :at="comment.at"
        :url="comment.url"
        :body="comment.body"
        markdown
        :nested="i > 0"
      />
      <ReviewCommentCard
        v-for="reply in replies"
        :key="reply.id"
        :comment="reply"
        :locked="actions!.locked.value"
        @update="(fields) => actions!.update(reply.id, fields)"
        @ask="(q) => actions!.ask(reply.id, q)"
        @send-now="actions!.sendNow(reply.id)"
      />
      <CommentComposer
        v-if="composing"
        :repo="repo?.value"
        askable
        submit-label="Add reply"
        @submit="(body) => (actions!.reply(thread, body), (composing = false))"
        @ask="(body, q) => (actions!.replyAndAsk(thread, body, q), (composing = false))"
        @cancel="composing = false"
      />
    </template>
    <footer v-if="actions && !composing" class="flex flex-wrap gap-1.5">
      <BaseButton v-if="!actions.locked.value" size="sm" tooltip="Write a reply, or ask Claude about the thread first. Commit it to send with your review, or send it now." @click="startReply">
        <PhArrowBendUpLeft :size="13" /> Reply
      </BaseButton>
      <BaseButton size="sm" :disabled="resolving" :tooltip="thread.resolved ? 'Reopens the thread on GitHub' : 'Marks the thread resolved on GitHub'" @click="setResolved(!thread.resolved)">
        <PhCheckCircle :size="13" /> {{ thread.resolved ? 'Unresolve' : 'Resolve' }}
      </BaseButton>
    </footer>
  </article>
</template>
