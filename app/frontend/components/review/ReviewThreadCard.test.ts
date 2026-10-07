import { computed } from 'vue'
import { describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import ReviewThreadCard from './ReviewThreadCard.vue'
import type { ThreadActions } from '@/composables/useReview'
import type { ReviewComment, ReviewThread } from '@/types/dashboard'

const thread = (fields: Partial<ReviewThread> = {}): ReviewThread => ({
  id: 'T_1', resolved: false, path: 'app/x.rb', side: 'RIGHT', line: 4, startLine: null, outdated: false, originalLine: 4,
  comments: [
    { id: 'c1', author: 'you-reviewer', body: 'This can be nil', at: '2026-10-01T09:00:00Z', url: 'https://github.com/acme/app/pull/7#c1' },
    { id: 'c2', author: 'author', body: 'Fixed, thanks', at: '2026-10-01T10:00:00Z', url: null },
  ],
  ...fields,
})
const reply = (fields: Partial<ReviewComment> = {}): ReviewComment => ({
  id: 9, path: 'app/x.rb', line: 4, side: 'RIGHT', startLine: null, body: 'Looks good now', state: 'staged', author: 'you',
  severity: null, evidence: null, notes: [], asking: false, threadId: 'T_1', ...fields,
})

function mountCard(t: ReviewThread, replies: ReviewComment[] = [], locked = false) {
  const actions: ThreadActions = {
    locked: computed(() => locked),
    replies: () => replies,
    reply: vi.fn(async () => undefined),
    replyAndAsk: vi.fn(async () => undefined),
    update: vi.fn(async () => undefined),
    ask: vi.fn(async () => undefined),
    sendNow: vi.fn(async () => undefined),
    setResolved: vi.fn(async () => undefined),
  }
  return { actions, card: mount(ReviewThreadCard, { props: { thread: t }, global: { provide: { threadActions: actions } } }) }
}

const button = (card: ReturnType<typeof mount>, text: string) => card.findAll('button').find((b) => b.text().includes(text))

describe('ReviewThreadCard', () => {
  it('replies to the thread from Echo', async () => {
    const { card } = mountCard(thread())
    await button(card, 'Reply')!.trigger('click')
    expect(card.text()).toContain('Fixed, thanks')
    expect(button(card, 'Add reply')).toBeTruthy()
  })

  it('shows your reply under the thread, open, with Commit and Send now', async () => {
    const { card, actions } = mountCard(thread(), [reply()])
    expect(card.text()).toContain('Your reply')
    expect(button(card, 'Commit')).toBeTruthy()
    await button(card, 'Send now')!.trigger('click')
    expect(actions.sendNow).toHaveBeenCalledWith(9)
  })

  it('resolves an open thread and unresolves a resolved one', async () => {
    const open = mountCard(thread())
    await button(open.card, 'Resolve')!.trigger('click')
    await flushPromises()
    expect(open.actions.setResolved).toHaveBeenCalledWith(expect.objectContaining({ id: 'T_1' }), true)

    const done = mountCard(thread({ resolved: true }))
    expect(done.card.text()).toContain('Resolved on GitHub')
    await button(done.card, 'Unresolve')!.trigger('click')
    expect(done.actions.setResolved).toHaveBeenCalledWith(expect.objectContaining({ id: 'T_1' }), false)
  })

  it("doesn't offer a reply once the review is sent, or actions on a reply already sent", () => {
    const { card } = mountCard(thread(), [reply({ state: 'sent' })], true)
    expect(button(card, 'Reply')).toBeUndefined()
    expect(button(card, 'Send now')).toBeUndefined()
    expect(button(card, 'Resolve')).toBeTruthy()
  })
})
