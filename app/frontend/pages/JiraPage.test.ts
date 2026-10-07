import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import JiraPage from './JiraPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { JiraBoards, JiraPageProps, JiraTicket } from '@/types/dashboard'

const ticket = (key: string, overrides: Partial<JiraTicket>): JiraTicket => ({
  key, url: `https://x/browse/${key}`, title: `Ticket ${key}`, type: 'Bug', status: 'Doing', category: 'in_progress',
  priority: 'P3', assignee: 'Sam Lee', reporter: 'Dana', sprint: null, description: '', updated: null,
  assignedToMe: false, boards: { '1': 0 }, ...overrides,
})

const SQUAD: JiraBoards['boards'][number] = { id: 1, name: 'Squad', location: null, filterId: 9, type: 'kanban', sprints: [], statuses: [
  { name: 'Backlog', category: 'new', hidden: true },
  { name: 'Ready', category: 'new', hidden: false },
  { name: 'Doing', category: 'indeterminate', hidden: false },
  { name: 'Verify', category: 'indeterminate', hidden: false },
] }
const SPRINTS: JiraBoards['boards'][number] = { id: 2, name: 'Sprints', location: null, filterId: 8, type: 'scrum', statuses: [{ name: 'Doing', category: 'indeterminate', hidden: false }],
  sprints: [{ id: 7, name: 'Sprint 9', state: 'active' }, { id: 8, name: 'Sprint 10', state: 'future' }] }
const BOARDS: JiraBoards = { boards: [SQUAD] }

const props = (overrides: Partial<JiraPageProps> = {}): JiraPageProps => ({
  shell: fixture.shell as JiraPageProps['shell'], agents: [], connected: true, syncedAt: new Date().toISOString(), jiraNotifications: [],
  jiraBoards: BOARDS,
  jiraTickets: [
    ticket('APP-1', { title: 'Fix login', status: 'Ready', category: 'todo', boards: { '1': 1 }, assignee: '' }),
    ticket('APP-2', { title: 'Speed up export', boards: { '1': 0 }, assignedToMe: true, assignee: 'Me', type: 'Story' }),
    ticket('APP-3', { title: 'Old idea', status: 'Backlog', category: 'todo', boards: { '1': 2 } }),
    ticket('APP-8', { title: 'My parked one', status: 'Backlog', category: 'todo', boards: { '1': 4 }, assignedToMe: true, assignee: 'Me' }),
    ticket('APP-4', { title: 'Check the release', status: 'Verify', category: 'post_development', boards: { '1': 3 } }),
    ticket('APP-5', { title: 'Elsewhere', boards: { '2': 0 }, sprint: 'Sprint 9' }),
    ticket('APP-6', { title: 'Next up', boards: { '2': 1 }, sprint: 'Sprint 10' }),
    ticket('APP-7', { title: 'Someday', boards: { '2': 2 } }),
  ],
  ...overrides,
})

// Only Jira searches answer; anything else (e.g. the health check) fails like an unreachable server would.
beforeEach(() =>
  vi.stubGlobal('fetch', vi.fn(async (url: string) => (url.startsWith('/api/jira/search') ? new Response(JSON.stringify({ items: [], more: false }), { status: 200 }) : new Response(null, { status: 404 })))),
)
afterEach(() => {
  vi.unstubAllGlobals()
  localStorage.clear()
})

const columns = (page: ReturnType<typeof mount>) => page.findAll('section h3 span.uppercase').map((s) => s.text())
const column = (page: ReturnType<typeof mount>, name: string) => page.find(`section[aria-label="${name}"]`).text()

describe('JiraPage', () => {
  it("shows the board as columns of cards, the to-do statuses as one To Do column with your Backlog tickets, and no tab for it", () => {
    const page = mount(JiraPage, { props: props() })

    expect(page.find('[role="radio"]').exists()).toBe(false)
    expect(columns(page)).toEqual(['To Do', 'Doing', 'Verify'])
    const todo = column(page, 'To Do')
    expect(todo).toContain('Fix login')
    expect(todo).toContain('My parked one')
    expect(page.text()).not.toContain('Old idea')
  })

  it('opens a scrum board on its active sprint, with a Sprint filter', async () => {
    const page = mount(JiraPage, { props: props({ jiraBoards: { ...BOARDS, boards: [SPRINTS] } }) })

    expect(page.text()).toContain('Elsewhere')
    expect(page.text()).not.toContain('Next up')
    expect(page.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 1')

    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    const sprint = (label: string) => page.findAll('[aria-label="Sprint"] button').find((b) => b.text().startsWith(label))!
    await sprint('Sprint 9').trigger('click')
    await sprint('No sprint').trigger('click')
    expect(page.text()).toContain('Someday')
    expect(page.text()).not.toContain('Elsewhere')
  })

  it('keeps Assigned to me and your name under Assignee in step, both ways', async () => {
    const page = mount(JiraPage, { props: props() })
    const toggle = () => page.find('button[aria-pressed]')
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    const me = () => page.findAll('[aria-label="Assignee"] button').find((b) => b.text().startsWith('Me'))!

    await toggle().trigger('click')
    expect(me().attributes('aria-pressed')).toBe('true')
    await me().trigger('click')
    expect(toggle().attributes('aria-pressed')).toBe('false')
    await me().trigger('click')
    expect(toggle().attributes('aria-pressed')).toBe('true')
    expect(page.text()).toContain('Speed up export')
    expect(page.text()).not.toContain('Fix login')
  })

  it("has no Sprint filter on a board without sprints", async () => {
    const page = mount(JiraPage, { props: props() })
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    expect(page.find('[aria-label="Sprint"]').exists()).toBe(false)
  })

  it('narrows to your tickets with Assigned to me, and by type from Filters', async () => {
    const page = mount(JiraPage, { props: props() })
    await page.find('button[aria-pressed]').trigger('click')
    expect(page.text()).toContain('Speed up export')
    expect(page.text()).not.toContain('Fix login')

    await page.find('button[aria-pressed]').trigger('click')
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    await page.findAll('[aria-label="Filters"] button').find((b) => b.text().startsWith('Story'))!.trigger('click')
    expect(page.text()).toContain('Speed up export')
    expect(page.text()).not.toContain('Check the release')
    expect(page.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 1')
  })

  it("lands on the Overview's links: yours, and unassigned", async () => {
    history.replaceState(null, '', '/jira?assignee=me')
    const mine = mount(JiraPage, { props: props() })
    await flushPromises()
    expect(mine.text()).toContain('Speed up export')
    expect(mine.text()).not.toContain('Fix login')

    history.replaceState(null, '', '/jira?assignee=unassigned')
    const unassigned = mount(JiraPage, { props: props() })
    await flushPromises()
    expect(unassigned.text()).toContain('Fix login')
    expect(unassigned.text()).not.toContain('Speed up export')
  })

  it('puts a child right under its parent in the same column, marks subtasks with a line, and leaves the rest in board order', () => {
    const parent = { key: 'APP-2', title: 'Speed up export', type: 'Story', status: 'Doing' }
    const page = mount(JiraPage, { props: props({ jiraTickets: [
      ticket('APP-2', { title: 'Speed up export', boards: { '1': 0 } }),
      ticket('APP-9', { title: 'Unrelated', boards: { '1': 1 } }),
      ticket('APP-3', { title: 'Export part', boards: { '1': 2 }, parent }),
      ticket('APP-5', { title: 'Grandchild', boards: { '1': 3 }, subtask: true, parent: { ...parent, key: 'APP-3', title: 'Export part' } }),
      ticket('APP-4', { title: 'Elsewhere child', status: 'Verify', category: 'post_development', boards: { '1': 4 }, subtask: true, parent }),
    ] }) })

    const doing = page.findAll('section[aria-label="Doing"] [data-depth]')
    expect(doing.map((c) => [c.text().match(/APP-\d+/)![0], c.attributes('data-depth')])).toEqual([['APP-2', '0'], ['APP-3', '1'], ['APP-5', '2'], ['APP-9', '0']])
    expect(page.find('section[aria-label="Verify"] [data-depth]').attributes('data-depth')).toBe('0')
    // Only subtasks get the line: APP-5 and APP-4, not the story APP-3, wherever their parent is.
    expect(page.findAll('[data-subtask]').map((c) => [c.text().match(/APP-\d+/)![0], c.attributes('style')])).toEqual([['APP-5', 'margin-left: 0.25rem;'], ['APP-4', 'margin-left: 0.25rem;']])
  })

  it('keeps the filters in the address bar, so a reload shows the same board, and a link from the Overview starts clean', async () => {
    const page = mount(JiraPage, { props: props() })
    await page.find('button[aria-pressed]').trigger('click')
    await page.find('button[aria-haspopup="dialog"]').trigger('click')
    await page.findAll('[aria-label="Filters"] button').find((b) => b.text().startsWith('Story'))!.trigger('click')
    expect(new URLSearchParams(location.search).get('assignee')).toBe('me')
    expect(new URLSearchParams(location.search).get('type')).toBe('Story')
    page.unmount()

    const reloaded = mount(JiraPage, { props: props() })
    expect(reloaded.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 2')
    expect(reloaded.text()).not.toContain('Fix login')
    reloaded.unmount()

    history.replaceState(null, '', '/jira?assignee=unassigned')
    const linked = mount(JiraPage, { props: props() })
    await flushPromises()
    expect(linked.text()).toContain('Fix login')
    expect(linked.find('button[aria-haspopup="dialog"]').text()).toBe('Filters 1')
    expect(location.search).toBe('?assignee=unassigned')
  })

  it('tidies away a one-off link, like ?ticket=, but keeps the filters', async () => {
    history.replaceState(null, '', '/jira?assignee=me&ticket=APP-2')
    mount(JiraPage, { props: props() })
    await flushPromises()
    expect(location.search).toBe('?assignee=me')
  })

  it('searches the board, offering all of Jira when nothing matches', async () => {
    const page = mount(JiraPage, { props: props() })
    await page.find('input[type="search"]').setValue('app-2')
    expect(page.text()).toContain('Speed up export')
    expect(page.text()).not.toContain('Fix login')

    await page.find('input[type="search"]').setValue('nothing like this')
    expect(page.text()).toContain('Search all of Jira')
  })

  it('points to Settings until a board is added, and to setup when Jira is not connected', () => {
    const none = mount(JiraPage, { props: props({ jiraBoards: { boards: [] } }) })
    expect(none.find('a[href="/settings#jira"]').exists()).toBe(true)

    const off = mount(JiraPage, { props: props({ connected: false, jiraTickets: [] }) })
    expect(off.find('a[href="/settings#connections"]').exists()).toBe(true)
  })
})
