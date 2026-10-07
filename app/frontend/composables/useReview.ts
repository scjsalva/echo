import { computed, onScopeDispose, ref, type ComputedRef } from 'vue'
import { request } from '@/lib/api'
import type { ReviewComment, ReviewDraft, ReviewThread } from '@/types/dashboard'

const POLL_MS = 3_000

/** Your rewrite skill, provided by the review page: its name (null hides the button) and what it rewrites. */
export interface Rewrite {
  skill: ComputedRef<string | null>
  comment: (id: number) => Promise<unknown>
  text: (text: string) => Promise<string>
}

/** What a thread card on the review page can do, provided by the page. */
export interface ThreadActions {
  locked: ComputedRef<boolean>
  replies: (thread: ReviewThread) => ReviewComment[]
  reply: (thread: ReviewThread, body: string) => Promise<unknown>
  replyAndAsk: (thread: ReviewThread, body: string, question: string) => Promise<unknown>
  update: (id: number, fields: Partial<Pick<ReviewComment, 'body' | 'state'>>) => Promise<unknown>
  ask: (id: number, question: string) => Promise<unknown>
  sendNow: (id: number) => Promise<unknown>
  setResolved: (thread: ReviewThread, resolved: boolean) => Promise<unknown>
}

/** A comment on a line, or with a threadId, a reply to that thread. */
export type NewComment = Pick<ReviewComment, 'path' | 'line' | 'side' | 'body'> & { threadId?: string }

/** A review in progress: its comments, and the actions on them. Polls while Claude is working. */
export function useReview(initial: ReviewDraft) {
  const review = ref(initial)
  const starting = ref(false)
  const busy = computed(() => ['queued', 'running'].includes(review.value.aiStatus) || review.value.comments.some((c) => c.asking))

  async function reload() {
    review.value = await request<ReviewDraft>('GET', `/api/reviews/${review.value.id}`)
  }

  const timer = setInterval(() => busy.value && reload().catch(() => null), POLL_MS)
  onScopeDispose(() => clearInterval(timer))

  function replace(comment: ReviewComment) {
    const others = review.value.comments.filter((c) => c.id !== comment.id)
    review.value = { ...review.value, comments: comment.state === 'removed' ? others : [...others, comment] }
  }

  const create = ({ threadId, ...fields }: NewComment) =>
    request<ReviewComment>('POST', `/api/reviews/${review.value.id}/comments`, { ...fields, thread_id: threadId })

  return {
    review,
    busy,
    starting,
    startAi: async (guidance = '') => {
      starting.value = true
      try {
        review.value = await request<ReviewDraft>('POST', `/api/reviews/${review.value.id}/ai_review`, { guidance })
      } finally {
        starting.value = false
      }
    },
    addComment: async (fields: NewComment) => replace(await create(fields)),
    // A new comment on a line, asked about straight away; it can start empty and take Claude's answer.
    addAndAsk: async (fields: NewComment, question: string) => {
      const comment = await create(fields)
      replace(comment)
      replace(await request<ReviewComment>('POST', `/api/review_comments/${comment.id}/question`, { question }))
    },
    updateComment: async (id: number, fields: Partial<Pick<ReviewComment, 'body' | 'state'>>) =>
      replace(await request<ReviewComment>('PATCH', `/api/review_comments/${id}`, fields)),
    ask: async (id: number, question: string) =>
      replace(await request<ReviewComment>('POST', `/api/review_comments/${id}/question`, { question })),
    // Asks your rewrite skill for a version of the comment; it lands in the comment's notes.
    rewriteComment: async (id: number) => replace(await request<ReviewComment>('POST', `/api/review_comments/${id}/rewrite`)),
    rewriteText: async (text: string) => (await request<{ text: string }>('POST', `/api/reviews/${review.value.id}/rewrite`, { text })).text,
    // Posts a reply to its thread on GitHub now, rather than with the review.
    sendReply: async (id: number) => replace(await request<ReviewComment>('POST', `/api/review_comments/${id}/reply`)),
    submit: async (event: 'comment' | 'approve' | 'request_changes', body: string) => {
      review.value = await request<ReviewDraft>('POST', `/api/reviews/${review.value.id}/submission`, { event, body })
    },
  }
}
