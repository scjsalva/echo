import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import JiraPage from './JiraPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { JiraPageProps, JiraTicket } from '@/types/dashboard'

const ticket = (key: string, overrides: Partial<JiraTicket>): JiraTicket => ({
  key, url: `https://x/browse/${key}`, title: `Ticket ${key}`, type: 'Bug', status: 'In Progress', category: 'in_progress',
  priority: 'P3', assignee: 'John Salva', reporter: 'Dana', sprint: 'FE 5', description: '', updated: new Date().toISOString(),
  assignedToMe: true, watching: false, reportedByMe: false, ...overrides,
})

const props = (overrides: Partial<JiraPageProps> = {}): JiraPageProps => ({
  shell: fixture.shell as JiraPageProps['shell'], agents: [], connected: true, syncedAt: new Date().toISOString(), jiraNotifications: [],
  jiraTickets: [
    ticket('APP-1', { title: 'Fix login', category: 'todo', status: 'To Do' }),
    ticket('APP-2', { title: 'Speed up export' }),
    ticket('APP-3', { title: 'Watched thing', assignedToMe: false, watching: true, assignee: 'Maya' }),
  ],
  ...overrides,
})

let fetchMock: ReturnType<typeof vi.fn>
beforeEach(() => {
  fetchMock = vi.fn(async (url: string) => {
    const title = url.includes('/search') ? 'Found in Jira' : 'Shipped long ago'
    return new Response(JSON.stringify({ items: [ticket('APP-9', { title, category: 'done', status: 'Done', updated: null })], more: false }), { status: 200 })
  })
  vi.stubGlobal('fetch', fetchMock)
})
afterEach(() => vi.unstubAllGlobals())

describe('JiraPage', () => {
  it('groups my tickets by status in board order', () => {
    const page = mount(JiraPage, { props: props() })

    const headings = page.findAll('h2').map((h) => h.text())
    expect(headings).toEqual(['To do', 'In progress', 'Done'])
    expect(page.text()).not.toContain('Watched thing')
  })

  it('filters to watched tickets and searches by key or title', async () => {
    const page = mount(JiraPage, { props: props() })

    await page.findAll('[role="radio"]').find((b) => b.text().startsWith('Watching'))!.trigger('click')
    expect(page.text()).toContain('Watched thing')

    await page.findAll('[role="radio"]').find((b) => b.text().startsWith('All'))!.trigger('click')
    await page.find('input[type="search"]').setValue('app-2')
    expect(page.text()).toContain('Speed up export')
    expect(page.text()).not.toContain('Fix login')
  })

  it('points to setup when Jira is not connected', () => {
    const page = mount(JiraPage, { props: props({ connected: false, jiraTickets: [] }) })

    expect(page.text()).toContain("Jira isn't connected")
    expect(page.find('a[href="/settings#connections"]').exists()).toBe(true)
  })

  it('keeps the type filter behind a button and filters by type', async () => {
    const page = mount(JiraPage, { props: props({ jiraTickets: [ticket('APP-1', { title: 'A bug' }), ticket('APP-2', { title: 'A task', type: 'Task' })] }) })
    expect(page.findAll('[role="radio"]').some((b) => b.text().startsWith('Task'))).toBe(false)

    await page.find('button[aria-label="Filter by ticket type"]').trigger('click')
    await page.findAll('[role="radio"]').find((b) => b.text().startsWith('Task'))!.trigger('click')

    expect(page.text()).toContain('A task')
    expect(page.text()).not.toContain('A bug')
  })

  it('loads done tickets from Jira, scoped like the rest of the page', async () => {
    const page = mount(JiraPage, { props: props() })
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(expect.stringContaining('/api/jira/done_tickets?scope=assigned'), expect.anything())
    expect(page.text()).toContain('Shipped long ago')
  })

  it('searches synced tickets first and only offers Jira when nothing matches', async () => {
    const page = mount(JiraPage, { props: props() })
    await flushPromises()

    await page.find('input[type="search"]').setValue('login')
    expect(page.text()).toContain('Fix login')
    expect(page.text()).not.toContain('Search all of Jira')
    expect(page.text()).not.toContain('Shipped long ago')

    await page.find('input[type="search"]').setValue('nothing like this')
    expect(page.text()).toContain('None of your synced tickets match “nothing like this”')
    fetchMock.mockClear()

    vi.useFakeTimers()
    await page.findAll('button').find((b) => b.text().includes('Search all of Jira'))!.trigger('click')
    await flushPromises()
    vi.useRealTimers()

    expect(fetchMock).toHaveBeenCalledWith(expect.stringContaining('/api/jira/search?q=nothing+like+this'), expect.anything())
    expect(page.text()).toContain('Found in Jira')
  })

  it('opens the ticket a notification points at and marks it read', async () => {
    history.replaceState(null, '', '/jira?ticket=APP-2&notification=n1')
    const notification = { id: 'n1', kind: 'mention' as const, key: 'APP-2', actor: 'Ravi', body: 'Can you check?', at: new Date().toISOString(), unread: true }

    const page = mount(JiraPage, { props: props({ jiraNotifications: [notification] }), attachTo: document.body })
    await flushPromises()

    expect(page.find('[role="dialog"]').text()).toContain('Speed up export')
    expect(page.find('[role="dialog"]').text()).toContain('Can you check?')
    expect(fetchMock).toHaveBeenCalledWith('/api/notifications/n1/read', expect.objectContaining({ method: 'PATCH' }))
    page.unmount()
  })
})
