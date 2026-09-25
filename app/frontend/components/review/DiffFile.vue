<script setup lang="ts">
import { computed, inject, ref, type ComputedRef } from 'vue'
import { PhCaretRight, PhPlus } from '@phosphor-icons/vue'
import CommentComposer from './CommentComposer.vue'
import ReviewCommentCard from './ReviewCommentCard.vue'
import type { DiffFile, DiffLine, ReviewComment } from '@/types/dashboard'

const props = defineProps<{ file: DiffFile; comments: ReviewComment[]; locked: boolean }>()
const emit = defineEmits<{
  add: [fields: { path: string; line: number; side: 'LEFT' | 'RIGHT'; body: string }]
  update: [id: number, fields: Partial<Pick<ReviewComment, 'body' | 'state'>>]
  ask: [id: number, question: string]
  addAndAsk: [fields: { path: string; line: number; side: 'LEFT' | 'RIGHT'; body: string }, question: string]
}>()
const repo = inject<ComputedRef<string | undefined>>('reviewRepo', computed(() => undefined))

const open = ref(true)
const composing = ref<string | null>(null)

// Removed lines are commented on the old side, everything else on the new side, as on GitHub.
const anchor = (line: DiffLine) => (line.kind === 'del' ? { side: 'LEFT' as const, line: line.old! } : { side: 'RIGHT' as const, line: line.new! })
const keyOf = (line: DiffLine) => `${anchor(line).side}:${anchor(line).line}`
const commentsAt = (line: DiffLine) => {
  const { side, line: number } = anchor(line)
  return props.comments.filter((c) => c.side === side && c.line === number)
}
const commentCount = computed(() => props.comments.length)

defineExpose({ expand: () => (open.value = true) })

const ROW: Record<DiffLine['kind'], string> = { add: 'bg-ok-soft/60', del: 'bg-bad-soft/60', context: '' }
const SIGN: Record<DiffLine['kind'], string> = { add: '+', del: '−', context: ' ' }
</script>

<template>
  <section class="overflow-hidden rounded-[10px] border border-line bg-surface">
    <button type="button" class="flex w-full items-center gap-2 border-b border-line-soft px-3 py-2 text-left hover:bg-subtle" @click="open = !open">
      <PhCaretRight :size="12" weight="bold" :class="['text-faint transition-transform', open && 'rotate-90']" />
      <span class="min-w-0 font-mono text-[12.5px] font-medium break-all">{{ file.path }}</span>
      <span v-if="file.previousPath" class="font-mono text-[11px] text-faint">from {{ file.previousPath }}</span>
      <span class="ml-auto flex shrink-0 items-center gap-2 font-mono text-[12px]">
        <span v-if="commentCount" class="text-accent">{{ commentCount }} comment{{ commentCount > 1 ? 's' : '' }}</span>
        <span class="text-ok">+{{ file.additions }}</span><span class="text-bad">−{{ file.deletions }}</span>
      </span>
    </button>

    <template v-if="open">
      <p v-if="file.tooLarge || !file.hunks.length" class="px-4 py-4 text-[13px] text-faint">
        {{ file.tooLarge ? "This diff is too large for GitHub to show here. Open the PR on GitHub to see it." : 'No changes to show (e.g. a binary file or a rename).' }}
      </p>
      <div v-else class="overflow-x-auto">
        <table class="w-full border-collapse font-mono text-[12px] leading-5">
          <tbody v-for="(hunk, h) in file.hunks" :key="h">
            <tr class="bg-subtle text-faint">
              <td colspan="4" class="px-3 py-1 text-[11.5px]">{{ hunk.header }}</td>
            </tr>
            <template v-for="(line, i) in hunk.lines" :key="`${h}-${i}`">
              <tr :class="['group', ROW[line.kind]]">
                <td class="w-10 border-r border-line-soft px-2 text-right text-faint select-none">{{ line.old ?? '' }}</td>
                <td class="w-10 border-r border-line-soft px-2 text-right text-faint select-none">{{ line.new ?? '' }}</td>
                <td class="w-6 text-center select-none">
                  <button
                    v-if="!locked"
                    type="button"
                    class="invisible rounded bg-accent p-0.5 text-on-accent group-hover:visible focus:visible"
                    :aria-label="`Comment on line ${anchor(line).line}`"
                    @click="composing = keyOf(line)"
                  >
                    <PhPlus :size="10" weight="bold" />
                  </button>
                </td>
                <td class="pr-4 whitespace-pre"><span class="text-faint select-none">{{ SIGN[line.kind] }} </span>{{ line.text }}</td>
              </tr>
              <tr v-if="commentsAt(line).length || composing === keyOf(line)">
                <td colspan="4" class="bg-canvas p-4">
                  <div class="grid max-w-3xl gap-2">
                    <ReviewCommentCard
                      v-for="comment in commentsAt(line)"
                      :key="comment.id"
                      :comment="comment"
                      :locked="locked"
                      @update="(fields) => emit('update', comment.id, fields)"
                      @ask="(q) => emit('ask', comment.id, q)"
                    />
                    <CommentComposer
                      v-if="composing === keyOf(line)"
                      :repo="repo"
                      askable
                      @submit="(body) => (emit('add', { path: file.path, ...anchor(line), body }), (composing = null))"
                      @ask="(body, q) => (emit('addAndAsk', { path: file.path, ...anchor(line), body }, q), (composing = null))"
                      @cancel="composing = null"
                    />
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </template>
  </section>
</template>
