import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import InboxPage from './InboxPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { OverviewProps } from '@/types/dashboard'

const base = fixture as unknown as OverviewProps
const props = { ...base, connections: base.connections } as unknown as InstanceType<typeof InboxPage>['$props']

let fetchMock: ReturnType<typeof vi.fn>
beforeEach(() => {
  fetchMock = vi.fn(async () => new Response(null, { status: 204 }))
  vi.stubGlobal('fetch', fetchMock)
})
afterEach(() => vi.unstubAllGlobals())

const clickChip = async (page: ReturnType<typeof mount>, label: string) =>
  page.findAll('[role="radio"]').find((b) => b.text().startsWith(label))!.trigger('click')

describe('InboxPage', () => {
  it('opens on what is waiting on you', () => {
    const page = mount(InboxPage, { props })

    expect(page.text()).toContain(base.waiting.items[0].title)
  })

  it('marks a notification read when it is opened', async () => {
    const page = mount(InboxPage, { props, attachTo: document.body })
    await clickChip(page, 'Jira')
    const unread = base.jiraNotifications.find((n) => n.unread)!

    await page.findAll('button').find((b) => b.text().includes(unread.key) && b.text().includes(unread.actor ?? ''))!.trigger('click')

    expect(fetchMock).toHaveBeenCalledWith(`/api/notifications/${unread.id}/read`, expect.objectContaining({ method: 'PATCH' }))
    expect(page.find('[role="dialog"]').exists()).toBe(true)
    page.unmount()
  })

  it('marks everything read at once', async () => {
    const page = mount(InboxPage, { props })
    await clickChip(page, 'All')

    await page.findAll('button').find((b) => b.text().includes('Mark all read'))!.trigger('click')

    expect(fetchMock).toHaveBeenCalledWith('/api/notifications/read_all', expect.objectContaining({ method: 'POST' }))
    expect(page.text()).not.toContain('Mark all read')
  })
})
