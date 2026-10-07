import { computed } from 'vue'
import { describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import CommentComposer from './CommentComposer.vue'
import ReviewCommentCard from './ReviewCommentCard.vue'
import SendReviewDialog from './SendReviewDialog.vue'
import type { Rewrite } from '@/composables/useReview'
import type { ReviewComment } from '@/types/dashboard'

const comment = (fields: Partial<ReviewComment> = {}): ReviewComment => ({
  id: 4, path: 'app/x.rb', line: 2, side: 'RIGHT', startLine: null, body: 'The method lacks a nil guard.', state: 'staged', author: 'ai',
  severity: 'high', evidence: null, notes: [], asking: false, threadId: null, ...fields,
})
const rewrite = (skill: string | null): Rewrite => ({ skill: computed(() => skill), comment: vi.fn(async () => undefined), text: vi.fn(async () => 'Can we add a nil check here?') })
const button = (w: ReturnType<typeof mount>, text: string) => w.findAll('button').find((b) => b.text().includes(text))

describe('Rewrite in your words', () => {
  it("shows no button until you've chosen a skill", () => {
    const card = mount(ReviewCommentCard, { props: { comment: comment(), locked: false }, global: { provide: { rewrite: rewrite(null) } } })
    expect(button(card, 'Rewrite')).toBeUndefined()
  })

  it("rewrites a finding or your own comment with your skill, but not an empty one", async () => {
    const r = rewrite('in-my-words')
    const card = mount(ReviewCommentCard, { props: { comment: comment(), locked: false }, global: { provide: { rewrite: r } } })
    await button(card, 'Rewrite')!.trigger('click')
    expect(r.comment).toHaveBeenCalledWith(4)

    const empty = mount(ReviewCommentCard, { props: { comment: comment({ author: 'you', body: '' }), locked: false }, global: { provide: { rewrite: r } } })
    expect(button(empty, 'Rewrite')).toBeUndefined()
  })

  it("puts the Commit and Uncommit buttons right: one at a time, whichever fits", () => {
    const staged = mount(ReviewCommentCard, { props: { comment: comment(), locked: false }, global: { provide: { rewrite: rewrite(null) } } })
    expect([button(staged, 'Commit'), button(staged, 'Uncommit')].map(Boolean)).toEqual([true, false])
    const committed = mount(ReviewCommentCard, { props: { comment: comment({ state: 'committed' }), locked: false }, global: { provide: { rewrite: rewrite(null) } } })
    expect(committed.findAll('button').map((b) => b.text()).filter((t) => /commit/i.test(t))).toEqual(['Uncommit'])
  })

  it('asks Claude in a multi-line text box, sent with Cmd+Enter', async () => {
    const card = mount(ReviewCommentCard, { props: { comment: comment(), locked: false }, global: { provide: { rewrite: rewrite(null) } } })
    await button(card, 'Ask AI')!.trigger('click')
    const box = card.find('textarea[aria-label="Question for Claude"]')
    await box.setValue('Is this really a bug?\nMake it shorter.')
    await box.trigger('keydown', { key: 'Enter', metaKey: true })
    expect(card.emitted('ask')![0]).toEqual(['Is this really a bug?\nMake it shorter.'])
  })

  it('rewrites what you type in the comment box in place, with Undo', async () => {
    const r = rewrite('in-my-words')
    const box = mount(CommentComposer, { props: { initial: 'The method lacks a nil guard.', askable: true }, global: { provide: { rewrite: r } } })
    await button(box, 'Rewrite')!.trigger('click')
    await flushPromises()
    expect(r.text).toHaveBeenCalledWith('The method lacks a nil guard.')
    await button(box, 'Add comment')!.trigger('click')
    expect(box.emitted('submit')![0]).toEqual(['Can we add a nil check here?'])
  })

  it('rewrites the review summary in place, and Undo puts it back', async () => {
    const r = rewrite('in-my-words')
    const dialog = mount(SendReviewDialog, { props: { committed: 1, staged: 0, ownPr: false, body: 'LGTM, nothing blocking.' }, global: { provide: { rewrite: r } } })
    await button(dialog, 'Rewrite')!.trigger('click')
    await flushPromises()
    expect(r.text).toHaveBeenCalledWith('LGTM, nothing blocking.')
    expect(dialog.emitted('update:body')!.at(-1)).toEqual(['Can we add a nil check here?'])

    await dialog.setProps({ body: 'Can we add a nil check here?' })
    await button(dialog, 'Undo')!.trigger('click')
    expect(dialog.emitted('update:body')!.at(-1)).toEqual(['LGTM, nothing blocking.'])
    dialog.unmount()
  })
})
