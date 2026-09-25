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
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ...overview, githubNotifications: many, jiraNotifications: [], pullRequests: [] }), { status: 200 })))
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })

    await menu.find('button[aria-label^="Notifications"]').trigger('click')
    await flushPromises()

    const rows = menu.findAll('[role="dialog"] li')
    expect(rows).toHaveLength(10)
    expect(rows[0].text()).toContain('Notification 0')
    expect(menu.find('[role="dialog"] a[href="/inbox"]').text()).toContain('See all notifications')
    menu.unmount()
  })

  it('marks what you open read, but leaves what still waits on you unread', async () => {
    const approval = { ...many[0], id: 'g-approved', reason: 'approved' as const, unread: true, resolution: null, title: 'Approved one' }
    const request = { ...many[0], id: 'g-request', reason: 'review_requested' as const, unread: true, resolution: null, title: 'Review me', at: new Date(Date.now() - 3_600_000).toISOString() }
    const fetchMock = vi.fn(async (_url: string) => new Response(JSON.stringify({ ...overview, githubNotifications: [approval, request], jiraNotifications: [], pullRequests: [] }), { status: 200 }))
    vi.stubGlobal('fetch', fetchMock)
    vi.stubGlobal('location', { ...location, assign: vi.fn(), origin: 'http://localhost' })
    const menu = mount(NotificationMenu, { props: { shell: overview.shell, linkClass: '' }, attachTo: document.body })
    const openRow = async (title: string) => {
      await menu.find('button[aria-label^="Notifications"]').trigger('click')
      await flushPromises()
      await menu.findAll('[role="dialog"] li button').find((b) => b.text().includes(title))!.trigger('click')
    }

    await openRow('Approved one')
    await openRow('Review me')

    const reads = fetchMock.mock.calls.map(([url]) => String(url)).filter((url) => url.endsWith('/read'))
    expect(reads).toEqual(['/api/notifications/g-approved/read'])
    menu.unmount()
  })
})
