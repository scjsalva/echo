import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import GithubPage from './GithubPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { GithubPageProps, PullRequest } from '@/types/dashboard'

const prs = fixture.pullRequests as unknown as PullRequest[]
const props = (overrides: Partial<GithubPageProps> = {}): GithubPageProps => ({
  shell: fixture.shell as GithubPageProps['shell'], agents: [], connected: true, syncedAt: new Date().toISOString(),
  pullRequests: prs, reviewQueue: prs.filter((pr) => !pr.mine && !pr.draft), githubNotifications: [],
  team: ['mchen'], repos: ['acme/web'], ...overrides,
})

const click = async (page: ReturnType<typeof mount>, label: string) =>
  page.findAll('[role="radio"]').find((b) => b.text().startsWith(label))!.trigger('click')

describe('GithubPage', () => {
  it('shows every open PR in watched repos under All, your team under Team, and yours under My PRs', async () => {
    const page = mount(GithubPage, { props: props() })
    await flushPromises()
    const titles = () => page.findAll('button').map((b) => b.text()).filter((t) => prs.some((pr) => t.includes(pr.title)))
    const inWatched = prs.filter((pr) => pr.fullName === 'acme/web')

    expect(titles()).toHaveLength(inWatched.length)
    await click(page, 'Team')
    expect(titles().length).toBeGreaterThan(0)
    expect(titles().every((t) => t.includes('mchen'))).toBe(true)
    await click(page, 'My PRs')
    expect(titles()).toHaveLength(prs.filter((pr) => pr.mine).length)
  })

  it('filters by status, review and author from the Filters menu, counting what is on', async () => {
    const page = mount(GithubPage, { props: props() })
    await flushPromises()
    await click(page, 'My PRs')
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    await page.findAll('[aria-label="Filters"] button').find((b) => b.text().startsWith('Draft'))!.trigger('click')
    await flushPromises()

    const draft = prs.find((pr) => pr.mine && pr.draft)!
    expect(page.text()).toContain(draft.title)
    expect(page.text()).not.toContain(prs.find((pr) => pr.mine && !pr.draft)!.title)
    expect(page.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 1')

    await page.findAll('[aria-label="Filters"] button').find((b) => b.text().startsWith('Draft'))!.trigger('click')
    expect(page.text()).toContain(prs.find((pr) => pr.mine && !pr.draft)!.title)
  })

  it("opens on Team with Ready selected from the dashboard's review queue", async () => {
    history.replaceState(null, '', '/github?tab=team&status=ready')
    const page = mount(GithubPage, { props: props() })
    await flushPromises()

    expect(page.find('[role="radio"][aria-checked="true"]').text()).toContain('Team')
    expect(page.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 1')
    const titles = page.findAll('button').map((b) => b.text()).filter((t) => prs.some((pr) => t.includes(pr.title)))
    expect(titles.length).toBeGreaterThan(0)
    expect(titles.every((t) => t.includes('mchen'))).toBe(true)
  })

  it('keeps the tab, filters and search in the address bar', async () => {
    const page = mount(GithubPage, { props: props() })
    await flushPromises()
    await click(page, 'Team')
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    await page.findAll('[aria-label="Filters"] button').find((b) => b.text().startsWith('Ready for review'))!.trigger('click')
    await page.find('input[type="search"]').setValue('fix')

    expect(Object.fromEntries(new URLSearchParams(location.search))).toEqual({ tab: 'team', status: 'ready', q: 'fix' })
    await click(page, 'All')
    expect(new URLSearchParams(location.search).has('tab')).toBe(false)
  })

  it('points to setup when GitHub is not connected', () => {
    const page = mount(GithubPage, { props: props({ connected: false }) })

    expect(page.find('a[href="/settings#connections"]').exists()).toBe(true)
  })

  it('shows the first 20 with Load more for the rest', async () => {
    const many = Array.from({ length: 25 }, (_, i) => ({ ...prs.find((pr) => !pr.mine)!, fullName: 'acme/web', key: `acme/web#${i}`, number: i, title: `Queue PR ${i}` }))
    const page = mount(GithubPage, { props: props({ pullRequests: many }) })
    await flushPromises()

    expect(page.findAll('button').filter((b) => b.text().includes('Queue PR'))).toHaveLength(20)
    await page.findAll('button').find((b) => b.text() === 'Load more')!.trigger('click')
    await flushPromises()

    expect(page.findAll('button').filter((b) => b.text().includes('Queue PR'))).toHaveLength(25)
    expect(page.text()).not.toContain('Load more')
  })

  it('pages My PRs the same way', async () => {
    const many = Array.from({ length: 23 }, (_, i) => ({ ...prs.find((pr) => pr.mine && !pr.draft)!, key: `acme/app#m${i}`, number: 100 + i, title: `My PR ${i}` }))
    const page = mount(GithubPage, { props: props({ pullRequests: many }) })
    await click(page, 'My PRs')
    await flushPromises()

    expect(page.findAll('button').filter((b) => b.text().includes('My PR '))).toHaveLength(20)
    expect(page.text()).toContain('Load more')
  })

  it('keeps what Load more loaded when the page refreshes', async () => {
    vi.useFakeTimers()
    const many = Array.from({ length: 45 }, (_, i) => ({ ...prs.find((pr) => !pr.mine)!, fullName: 'acme/web', key: `acme/web#${i}`, number: i, title: `PR number ${i}` }))
    const data = props({ pullRequests: many, reviewQueue: many })
    // The sync picked up one more PR since the page loaded.
    const synced = [...many, { ...many[0], key: 'acme/web#99', number: 99, title: 'PR number 99' }]
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ...data, pullRequests: synced, reviewQueue: synced }), { status: 200 })))
    const page = mount(GithubPage, { props: data })
    await flushPromises()
    await page.findAll('button').find((b) => b.text() === 'Load more')!.trigger('click')
    await flushPromises()
    expect(page.text()).toContain('PR number 39')

    await vi.advanceTimersByTimeAsync(60_000)
    await flushPromises()

    expect(page.text()).toContain('PR number 39')
  })
})

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})
