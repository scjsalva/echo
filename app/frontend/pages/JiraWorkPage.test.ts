import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import JiraWorkPage from './JiraWorkPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { JiraTicket, JiraWorkPageProps, WorkList, WorkTicket } from '@/types/dashboard'

const work = (key: string, overrides: Partial<WorkTicket> = {}): WorkTicket => ({
  key, url: `https://x/browse/${key}`, title: `Ticket ${key}`, type: 'Task', status: 'Ready', priority: 'P3', due: null,
  summary: `About ${key}`, expected: `Change ${key}`, size: 'S', ready: true, question: null, tags: [], summarisedAt: new Date().toISOString(), ...overrides,
})
const unsummarised = (key: string) => work(key, { summary: null, expected: null, size: null, ready: null, summarisedAt: null })
const ticket = (key: string): JiraTicket => ({
  key, url: `https://x/browse/${key}`, title: `Ticket ${key}`, type: 'Task', status: 'Ready', category: 'todo', priority: 'P3',
  assignee: '', reporter: 'Dana', sprint: null, description: '', updated: null, assignedToMe: false, boards: { '1': 0 },
})

const list = (tickets: WorkTicket[], overrides: Partial<WorkList> = {}): WorkList => ({ tickets, top: 5, running: false, summarised: 0, error: null, ...overrides })
const KEYS = ['APP-1', 'APP-2', 'APP-3', 'APP-4', 'APP-5', 'APP-6']

const props = (w: WorkList): JiraWorkPageProps => ({
  shell: fixture.shell as JiraWorkPageProps['shell'], agents: [], connected: true, syncedAt: null, jiraNotifications: [],
  jiraBoards: { boards: [] }, jiraTickets: [...KEYS, 'APP-7'].map(ticket), work: w,
})

const posts: unknown[] = []
beforeEach(() => {
  posts.length = 0
  vi.stubGlobal('fetch', vi.fn(async (url: string, init?: RequestInit) => {
    if (url === '/api/jira/work' && init?.method === 'POST') {
      posts.push(init.body ? JSON.parse(String(init.body)) : null)
      return new Response(JSON.stringify(list([], { running: true })), { status: 200 })
    }
    return new Response(null, { status: 404 })
  }))
})
afterEach(() => {
  vi.unstubAllGlobals()
  history.replaceState(null, '', '/jira/work')
})

describe('JiraWorkPage', () => {
  it('shows the first five as picks, summarised or not, and the rest ten at a time', async () => {
    const keys = Array.from({ length: 17 }, (_, i) => `APP-${i + 1}`)
    const tickets = [...keys.slice(0, 3).map((k) => work(k)), ...keys.slice(3).map(unsummarised)]
    const page = mount(JiraWorkPage, { props: props(list(tickets)) })

    const picks = page.find('section[aria-label="Top picks"]')
    expect(picks.findAll('article')).toHaveLength(5)
    expect(picks.text()).toContain('About APP-1')
    expect(picks.text()).toContain("What you'd do: Change APP-1")
    expect(picks.findAll('article')[4].text()).toContain('Not summarised yet.')
    const rows = () => page.findAll('section[aria-label="Everything else"] tbody tr')
    expect(rows().map((r) => r.find('td').text())).toEqual(keys.slice(5, 15))
    expect(rows()[0].text()).toContain('Summarise')
    expect(page.text()).toContain('14 not summarised yet')

    await page.findAll('button').find((b) => b.text().startsWith('Load more'))!.trigger('click')
    expect(rows()).toHaveLength(12)
    expect(page.findAll('button').some((b) => b.text().startsWith('Load more'))).toBe(false)
  })

  it('picks by quick wins, urgency, bugs, what needs clarifying, and Claude\'s tags', async () => {
    const tickets = [
      work('APP-1', { size: 'M' }),
      work('APP-2', { size: 'S', type: 'Bug' }),
      work('APP-3', { ready: false, question: 'Which page?', priority: 'Highest' }),
      work('APP-4', { size: 'L', tags: ['data_correction', 'backend'] }),
    ]
    const page = mount(JiraWorkPage, { props: props(list(tickets)) })
    const keys = () => page.findAll('article').map((a) => a.find('.text-jira').text())
    const choose = (label: string) => page.findAll('[role="radio"]').find((b) => b.text().startsWith(label))!.trigger('click')

    expect(keys()).toEqual(['APP-1', 'APP-2', 'APP-3', 'APP-4'])
    expect(page.find('[role="radio"][aria-checked="true"]').text()).toBe('Best overall 4')
    await choose('Quick wins')
    expect(keys()).toEqual(['APP-2'])
    expect(location.search).toBe('?pick=quick')
    await choose('Urgent')
    expect(keys()).toEqual(['APP-3'])
    await choose('Bugs')
    expect(keys()).toEqual(['APP-2'])
    await choose('Needs clarifying')
    expect(keys()).toEqual(['APP-3'])
    await choose('Data corrections')
    expect(keys()).toEqual(['APP-4'])
    expect(page.find('article').text()).toContain('Data correction')
    await choose('Investigations')
    expect(page.text()).toContain('Nothing fits “Investigations”')
  })

  it('flags a ticket that needs an answer first, and an overdue one', () => {
    const page = mount(JiraWorkPage, { props: props(list([work('APP-1', { ready: false, question: 'Which page?', due: '2020-01-01' })])) })

    const card = page.find('article').text()
    expect(card).toContain('Needs an answer first')
    expect(card).toContain('Open question: Which page?')
    expect(page.find('article .text-bad').text()).toMatch(/^Due/)
  })

  it('finds work, or refreshes one ticket without opening it', async () => {
    const page = mount(JiraWorkPage, { props: props(list([work('APP-1')])) })

    await page.find('article button').trigger('click')
    await flushPromises()
    expect(posts).toEqual([{ key: 'APP-1' }])
    expect(page.find('[role="dialog"]').exists()).toBe(false)
    expect(page.text()).toContain('Finding work…')
  })

  it('shows why it failed', () => {
    const page = mount(JiraWorkPage, { props: props(list([], { error: 'Claude took longer than 5 minutes' })) })

    expect(page.find('[role="alert"]').text()).toBe('Claude took longer than 5 minutes')
    expect(page.text()).toContain('Nothing unassigned in To Do.')
  })
})
