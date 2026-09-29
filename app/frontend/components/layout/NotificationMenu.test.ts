import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import NotificationMenu from './NotificationMenu.vue'
import fixture from '@/test/overview.fixture.json'
import type { GithubNotification, OverviewProps } from '@/types/dashboard'

const overview = fixture as unknown as OverviewProps
const many: GithubNotification[] = Array.from({ length: 14 }, (_, i) => ({
  ...overview.githubNotifications[0], id: `g${i}`, title: `Notification ${i}`, at: new Date(Date.now() - i * 60_000).toISOString(),
}))

afterEach(() => vi.unstubAllGlobals())

describe('NotificationMenu', () => {
  it('shows the 10 latest notifications and links to the rest', async () => {
    const read = many.map((n) => ({ ...n, unread: false }))
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ...overview, githubNotifications: read, jiraNotifications: [], pullRequests: [] }), { status: 200 })))
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })

    await menu.trigger('mouseenter')
    await flushPromises()

    const rows = menu.findAll('[role="dialog"] li')
    expect(rows).toHaveLength(10)
    expect(rows[0].text()).toContain('Notification 0')
    expect(menu.find('[role="dialog"] a[href="/inbox"]').text()).toContain('See all notifications')
    menu.unmount()
  })

  it('marks what it shows read once you move away, but leaves what still waits on you unread', async () => {
    const approval = { ...many[0], id: 'g-approved', reason: 'approved' as const, unread: true, resolution: null, title: 'Approved one' }
    const request = { ...many[0], id: 'g-request', reason: 'review_requested' as const, unread: true, resolution: null, title: 'Review me', at: new Date(Date.now() - 3_600_000).toISOString() }
    const fetchMock = vi.fn(async (_url: string, _init?: RequestInit) => new Response(JSON.stringify({ ...overview, githubNotifications: [approval, request], jiraNotifications: [], pullRequests: [] }), { status: 200 }))
    vi.stubGlobal('fetch', fetchMock)
    vi.stubGlobal('location', { ...location, assign: vi.fn(), origin: 'http://localhost' })
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })
    vi.useFakeTimers()
    await menu.trigger('mouseenter')
    await flushPromises()
    expect(fetchMock.mock.calls.some(([url]) => String(url).endsWith('/read_some'))).toBe(false)
    await vi.advanceTimersByTimeAsync(30_000)
    expect(fetchMock.mock.calls.some(([url]) => String(url).endsWith('/read_some')), 'dots stay while it is open').toBe(false)
    await menu.trigger('mouseleave')
    await vi.advanceTimersByTimeAsync(200)
    vi.useRealTimers()

    const reads = fetchMock.mock.calls.filter(([url]) => String(url).endsWith('/read_some'))
    expect(reads).toHaveLength(1)
    expect(JSON.parse(reads[0][1]!.body as string)).toEqual({ ids: ['g-approved'] })
    menu.unmount()
  })

  it('marks them read when you move away after a look, but not after just passing over', async () => {
    const approval = { ...many[0], id: 'g-approved', reason: 'approved' as const, unread: true, resolution: null }
    const fetchMock = vi.fn(async (_url: string, _init?: RequestInit) => new Response(JSON.stringify({ ...overview, githubNotifications: [approval], jiraNotifications: [], pullRequests: [] }), { status: 200 }))
    vi.stubGlobal('fetch', fetchMock)
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })
    const reads = () => fetchMock.mock.calls.filter(([url]) => String(url).endsWith('/read_some')).length
    vi.useFakeTimers()

    await menu.trigger('mouseenter')
    await vi.advanceTimersByTimeAsync(1_500)
    await menu.trigger('mouseleave')
    await vi.advanceTimersByTimeAsync(200)
    expect(reads(), 'passing over').toBe(0)

    await menu.trigger('mouseenter')
    await vi.advanceTimersByTimeAsync(3_000)
    await menu.trigger('mouseleave')
    await vi.advanceTimersByTimeAsync(200)
    vi.useRealTimers()
    expect(reads(), 'looked, then moved away').toBe(1)
    expect(menu.find('a[href="/inbox"]').attributes('aria-label'), 'the count drops without waiting for the page').toContain(`${overview.shell.unreadCount - 1} unread`)
    menu.unmount()
  })

  it('shows unread ones however old, so the count matches what you see', async () => {
    const old = { ...many[0], id: 'g-old', title: 'Old but unread', unread: true, at: new Date(Date.now() - 3 * 86_400_000).toISOString() }
    const recent = many.map((n) => ({ ...n, unread: false }))
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ...overview, githubNotifications: [...recent, old], jiraNotifications: [], pullRequests: [] }), { status: 200 })))
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })

    await menu.trigger('mouseenter')
    await flushPromises()

    const rows = menu.findAll('[role="dialog"] li')
    expect(rows).toHaveLength(10)
    expect(rows.at(-1)!.text()).toContain('Old but unread')
    menu.unmount()
  })
})
