import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import ReviewPage from './ReviewPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { DiffFile, PullRequest, ReviewComment, ReviewDraft, ReviewPageProps } from '@/types/dashboard'

const pr = { ...(fixture.pullRequests as unknown as PullRequest[]).find((p) => !p.mine)!, description: '## What\n\nAdds a fallback.' }
const file: DiffFile = {
  path: 'app/menu.rb', previousPath: null, status: 'modified', additions: 1, deletions: 1, tooLarge: false,
  hunks: [{ header: '@@ -1,2 +1,2 @@', context: '', lines: [
    { kind: 'context', old: 1, new: 1, text: 'def menu' },
    { kind: 'del', old: 2, new: null, text: '  items' },
    { kind: 'add', old: null, new: 2, text: '  items.presence || fallback' },
  ] }],
}
const comment = (fields: Partial<ReviewComment>): ReviewComment => ({
  id: 1, path: 'app/menu.rb', line: 2, side: 'RIGHT', startLine: null, body: 'fallback can be nil', state: 'staged', author: 'ai',
  severity: 'high', evidence: null, notes: [], asking: false, ...fields,
})
const draft = (fields: Partial<ReviewDraft> = {}): ReviewDraft => ({
  id: 5, prKey: pr.key, headSha: 'abc', status: 'draft', aiStatus: 'done', aiError: null, sentAt: null, githubUrl: null, comments: [comment({})], ...fields,
})
const props = (review = draft()): ReviewPageProps => ({ shell: fixture.shell as ReviewPageProps['shell'], agents: [], pullRequest: pr, headSha: 'abc', files: [file], review })

let fetchMock: ReturnType<typeof vi.fn>
beforeEach(() => {
  fetchMock = vi.fn(async (url: string, init: RequestInit) => {
    if (url === '/api/alerts') return new Response(JSON.stringify({ alerts: [], show: false, sound: null }), { status: 200 })
    const body = JSON.parse((init?.body as string) ?? '{}')
    if (url.startsWith('/api/review_comments/')) return new Response(JSON.stringify(comment({ ...body })), { status: 200 })
    if (url.endsWith('/submission')) return new Response(JSON.stringify(draft({ status: 'sent', githubUrl: 'https://github.com/x' })), { status: 200 })
    return new Response(JSON.stringify(comment({ id: 2, author: 'you', ...body })), { status: 201 })
  })
  vi.stubGlobal('fetch', fetchMock)
})
afterEach(() => vi.unstubAllGlobals())

const button = (page: ReturnType<typeof mount>, label: string) => page.findAll('button').find((b) => b.text().includes(label))!

describe('ReviewPage', () => {
  it('shows the PR above a file tree and its diff with staged comments', () => {
    const page = mount(ReviewPage, { props: props() })

    expect(page.find('header[aria-label="Pull request"]').text()).toContain(pr.title)
    expect(page.find('header[aria-label="Pull request"]').text()).toContain('1 staged')
    expect(page.find('aside nav[aria-label="Files"]').text()).toContain('menu.rb')
    expect(page.find('main').text()).toContain('items.presence || fallback')
    expect(page.find('main').text()).toContain('fallback can be nil')
  })

  it("says when Claude found nothing, and what it left out", async () => {
    const page = mount(ReviewPage, {
      props: props(draft({ comments: [], aiReport: { summary: 'Checked the menu fallback and its callers.', added: 0, leftOut: [{ path: 'app/menu.rb', line: 2, body: 'Maybe nil', reason: "Claude couldn't confirm it in the code" }] } })),
    })
    await page.find('button[aria-label="Claude\'s verdict"]').trigger('click')
    const verdict = page.find('[role="dialog"][aria-label="Claude\'s verdict"]')

    expect(verdict.text()).toContain('Claude found no problems')
    expect(verdict.text()).toContain('Checked the menu fallback and its callers.')
    expect(verdict.text()).toContain('1 finding left out')

    await button(page, 'Use as review summary').trigger('click')
    expect((page.find('textarea[aria-label="Review summary"]').element as HTMLTextAreaElement).value).toBe('Checked the menu fallback and its callers.')
  })

  it('locks the review once the PR is merged', () => {
    const page = mount(ReviewPage, { props: { ...props(), mergedAt: new Date(Date.now() - 3_600_000).toISOString() } })

    expect(page.find('header[aria-label="Pull request"]').text()).toContain("Merged 1h ago, so it can't be reviewed any more")
    expect(page.findAll('button').some((b) => b.text().includes('Send review'))).toBe(false)
    expect(page.findAll('button').some((b) => b.text().includes('AI review'))).toBe(false)
    expect(page.find('button[aria-label^="Comment on line"]').exists()).toBe(false)
  })

  it('opens the description in a drawer, keeping the file tree', async () => {
    const page = mount(ReviewPage, { props: props() })

    expect(page.text()).not.toContain('Adds a fallback')
    await button(page, 'Description').trigger('click')
    expect(page.find('[role="dialog"][aria-label="Description"]').text()).toContain('Adds a fallback')
    expect(page.find('aside nav[aria-label="Files"]').exists()).toBe(true)
    await page.find('[role="dialog"] button[aria-label="Close"]').trigger('click')
    expect(page.find('[role="dialog"]').exists()).toBe(false)
  })

  it('jumps to a file from the tree', async () => {
    const page = mount(ReviewPage, { props: props(), attachTo: document.body })
    const scroll = vi.fn()
    document.getElementById('file-app/menu.rb')!.scrollIntoView = scroll

    await page.find('aside nav button[aria-current], aside nav li:last-child button').trigger('click')

    expect(scroll).toHaveBeenCalled()
    expect(page.find('aside nav button[aria-current="true"]').text()).toContain('menu.rb')
    page.unmount()
  })

  it('commits a staged comment', async () => {
    const page = mount(ReviewPage, { props: props() })

    await button(page, 'Commit').trigger('click')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/review_comments/1', expect.objectContaining({ method: 'PATCH', body: JSON.stringify({ state: 'committed' }) }))
    expect(page.find('header[aria-label="Pull request"]').text()).toContain('1 committed')
  })

  it('adds your own comment on a line', async () => {
    const page = mount(ReviewPage, { props: props(draft({ comments: [] })), attachTo: document.body })

    await page.find('button[aria-label="Comment on line 1"]').trigger('click')
    await page.find('textarea[aria-label="Comment"]').setValue('Why rename this?')
    await button(page, 'Add comment').trigger('click')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/reviews/5/comments', expect.objectContaining({ body: JSON.stringify({ path: 'app/menu.rb', side: 'RIGHT', line: 1, body: 'Why rename this?' }) }))
    page.unmount()
  })

  it('sends the review with the chosen decision only when asked', async () => {
    const page = mount(ReviewPage, { props: props(draft({ comments: [comment({ state: 'committed' })] })), attachTo: document.body })

    await button(page, 'Send review').trigger('click')
    expect(fetchMock.mock.calls.some(([url]) => String(url).endsWith('/submission'))).toBe(false)
    await page.find('input[value="request_changes"]').setValue(true)
    await page.find('textarea[aria-label="Review summary"]').setValue('Please fix the nil case')
    await button(page, 'Submit review').trigger('click')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith('/api/reviews/5/submission', expect.objectContaining({ body: JSON.stringify({ event: 'request_changes', body: 'Please fix the nil case' }) }))
    expect(page.text()).toContain('Sent to GitHub')
    page.unmount()
  })
})
