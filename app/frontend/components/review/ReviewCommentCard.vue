<script setup lang="ts">
import { computed, inject, ref, type ComputedRef } from 'vue'
import { PhCheck, PhPencilSimple, PhSparkle, PhTrash, PhArrowUUpLeft, PhPaperPlaneTilt } from '@phosphor-icons/vue'
import CommentComposer from './CommentComposer.vue'
import SkillPicker from '@/components/ui/SkillPicker.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import MarkdownBlock from '@/components/ui/MarkdownBlock.vue'
import type { Tone } from '@/lib/labels'
import type { Rewrite } from '@/composables/useReview'
import type { ReviewComment } from '@/types/dashboard'

defineProps<{ comment: ReviewComment; locked: boolean }>()
const repo = inject<ComputedRef<string | undefined>>('reviewRepo', computed(() => undefined))
const rewrite = inject<Rewrite | null>('rewrite', null)
const emit = defineEmits<{ update: [fields: Partial<Pick<ReviewComment, 'body' | 'state'>>]; ask: [question: string]; sendNow: [] }>()

const SEVERITY: Record<string, Tone> = { high: 'bad', medium: 'warn', low: 'accent', nit: 'neutral' }

const card = ref<HTMLElement>()
const justReplaced = ref(false)

// The answer replaces the comment further up the card, so bring that into view
// and flash it, or the change is easy to miss.
function useAnswer(text: string) {
  emit('update', { body: text })
  card.value?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  justReplaced.value = true
  setTimeout(() => (justReplaced.value = false), 1_500)
}

const editing = ref(false)
const asking = ref(false)
const question = ref('')

function ask() {
  if (!question.value.trim()) return
  emit('ask', question.value.trim())
  question.value = ''
  asking.value = false
}
</script>

<template>
  <article
    ref="card"
    :class="[
      'grid scroll-mt-4 gap-2 rounded-lg border bg-surface px-3 py-2.5 font-sans shadow-sm',
      comment.state === 'committed' ? 'border-ok/50' : comment.state === 'sent' ? 'border-line opacity-80' : comment.author === 'ai' ? 'ai-border' : 'border-accent/40',
    ]"
  >
    <header class="flex flex-wrap items-center gap-2 text-[12px]">
      <BasePill v-if="comment.author === 'ai'" class="ai-soft"><PhSparkle :size="11" weight="fill" class="ai-icon" /><span class="ai-text">Claude</span></BasePill>
      <BasePill v-else>{{ comment.threadId ? 'Your reply' : 'You' }}</BasePill>
      <BasePill v-if="comment.severity" :tone="SEVERITY[comment.severity] ?? 'neutral'" class="capitalize">{{ comment.severity }}</BasePill>
      <BasePill :tone="comment.state === 'committed' ? 'ok' : 'neutral'">
        {{ { staged: 'Staged', committed: 'Committed', sent: 'Sent', removed: 'Removed' }[comment.state] }}
      </BasePill>
      <span v-if="!comment.threadId" class="text-faint">{{ comment.side === 'LEFT' ? 'old' : 'line' }} {{ comment.line }}</span>
    </header>

    <CommentComposer v-if="editing" :initial="comment.body" :rows="10" submit-label="Save" @submit="(body) => (emit('update', { body }), (editing = false))" @cancel="editing = false" />
    <div
      v-else-if="comment.body"
      :class="['-mx-1.5 rounded-md px-1.5 transition-colors duration-700', justReplaced ? 'bg-accent-soft' : 'bg-transparent']"
    >
      <MarkdownBlock :source="comment.body" />
    </div>
    <p v-else class="text-[13px] text-faint">No comment yet. Use Claude's answer, or edit to write your own.</p>
    <details v-if="comment.evidence && !editing" class="group rounded-md bg-subtle px-2.5 py-1.5 text-[12.5px]">
      <summary class="cursor-pointer text-muted select-none group-open:mb-1">How Claude checked this</summary>
      <MarkdownBlock :source="comment.evidence" />
    </details>

    <div v-if="comment.notes.length || comment.asking" class="grid gap-2 border-t border-line-soft pt-2">
      <div
        v-for="(note, i) in comment.notes"
        :key="i"
        :class="['grid gap-1 rounded-md px-2.5 py-2 text-[12.5px]', { you: 'bg-subtle', claude: 'ai-soft', error: 'bg-bad-soft' }[note.role]]"
      >
        <span class="font-mono text-[10.5px] tracking-wide text-faint uppercase">{{ note.role === 'you' ? 'You asked' : note.role === 'claude' ? 'Claude' : 'Error' }}</span>
        <p :class="['whitespace-pre-line wrap-anywhere', note.role === 'error' && 'text-bad']">{{ note.text }}</p>
        <BaseButton v-if="note.role === 'claude' && !locked" size="sm" class="justify-self-start" :tooltip="`Replaces the ${comment.threadId ? 'reply' : 'comment'} with this answer`" @click="useAnswer(note.text)">
          Use as {{ comment.threadId ? 'reply' : 'comment' }}
        </BaseButton>
      </div>
      <p v-if="comment.asking" class="ai-soft inline-flex items-center gap-1.5 justify-self-start rounded-md px-2 py-1 text-[12.5px] font-medium">
        <PhSparkle :size="13" weight="fill" class="ai-icon animate-pulse" /> <span class="ai-text">Claude is thinking…</span>
      </p>
    </div>

    <div v-if="asking" class="grid gap-1">
    <!-- A text box, so a question can run to a few lines; ⌘/Ctrl+Enter sends it. -->
    <form class="flex items-end gap-2" @submit.prevent="ask">
      <textarea
        v-model="question"
        rows="3"
        aria-label="Question for Claude"
        placeholder="e.g. Is this really a bug? Make it shorter."
        class="min-w-0 flex-1 resize-y rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
        @keydown.esc.stop="asking = false"
        @keydown.meta.enter.prevent="ask"
        @keydown.ctrl.enter.prevent="ask"
      />
      <BaseButton size="sm" :disabled="!question.trim()" @click="ask">Ask</BaseButton>
    </form>
    <SkillPicker action="review_question" :repo="repo" class="justify-self-end" />
    </div>

    <footer v-if="!locked && !editing && comment.state !== 'sent'" class="flex flex-wrap gap-1.5">
      <BaseButton
        v-if="comment.state === 'staged'"
        size="sm"
        variant="primary"
        :disabled="!comment.body"
        :tooltip="comment.body ? 'Include it when you send the review' : `Write the ${comment.threadId ? 'reply' : 'comment'} first`"
        @click="emit('update', { state: 'committed' })"
      >
        <PhCheck :size="13" /> Commit
      </BaseButton>
      <BaseButton v-else size="sm" tooltip="Keep it out of the review for now" @click="emit('update', { state: 'staged' })">
        <PhArrowUUpLeft :size="13" /> Uncommit
      </BaseButton>
      <BaseButton v-if="comment.threadId" size="sm" :disabled="!comment.body" tooltip="Posts this reply on GitHub now, without waiting for the review" @click="emit('sendNow')">
        <PhPaperPlaneTilt :size="13" /> Send now
      </BaseButton>
      <BaseButton size="sm" @click="editing = true"><PhPencilSimple :size="13" /> Edit</BaseButton>
      <BaseButton size="sm" class="ai-border" :disabled="comment.asking" @click="asking = !asking"><PhSparkle :size="13" weight="fill" class="ai-icon" /> Ask AI</BaseButton>
      <BaseButton
        v-if="rewrite?.skill.value && comment.body"
        size="sm"
        class="ai-border"
        :disabled="comment.asking"
        :tooltip="`Rewrites it with your ${rewrite.skill.value} skill. The draft shows below, ready to use.`"
        @click="rewrite.comment(comment.id)"
      >
        <PhSparkle :size="13" weight="fill" class="ai-icon" /> Rewrite
      </BaseButton>
      <BaseButton size="sm" :tooltip="`Drop this ${comment.threadId ? 'reply' : 'comment'}`" @click="emit('update', { state: 'removed' })"><PhTrash :size="13" /> Remove</BaseButton>
    </footer>
  </article>
</template>
