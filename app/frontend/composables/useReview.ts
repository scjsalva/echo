import { computed, onScopeDispose, ref } from 'vue'
import { request } from '@/lib/api'
import type { ReviewComment, ReviewDraft } from '@/types/dashboard'

const POLL_MS = 3_000

/** A review in progress: its comments, and the actions on them. Polls while Claude is working. */
export function useReview(initial: ReviewDraft) {
  const review = ref(initial)
  const starting = ref(false)
  const busy = computed(() => review.value.aiStatus === 'running' || review.value.comments.some((c) => c.asking))

  async function reload() {
    review.value = await request<ReviewDraft>('GET', `/api/reviews/${review.value.id}`)
  }

  const timer = setInterval(() => busy.value && reload().catch(() => null), POLL_MS)
  onScopeDispose(() => clearInterval(timer))

  function replace(comment: ReviewComment) {
    const others = review.value.comments.filter((c) => c.id !== comment.id)
    review.value = { ...review.value, comments: comment.state === 'removed' ? others : [...others, comment] }
  }

  return {
    review,
    busy,
    starting,
    startAi: async () => {
      starting.value = true
      try {
        review.value = await request<ReviewDraft>('POST', `/api/reviews/${review.value.id}/ai_review`)
      } finally {
        starting.value = false
      }
    },
    addComment: async (fields: Pick<ReviewComment, 'path' | 'line' | 'side' | 'body'>) =>
      replace(await request<ReviewComment>('POST', `/api/reviews/${review.value.id}/comments`, fields)),
    updateComment: async (id: number, fields: Partial<Pick<ReviewComment, 'body' | 'state'>>) =>
      replace(await request<ReviewComment>('PATCH', `/api/review_comments/${id}`, fields)),
    ask: async (id: number, question: string) =>
      replace(await request<ReviewComment>('POST', `/api/review_comments/${id}/question`, { question })),
    submit: async (event: 'comment' | 'approve' | 'request_changes', body: string) => {
      review.value = await request<ReviewDraft>('POST', `/api/reviews/${review.value.id}/submission`, { event, body })
    },
  }
}
