import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AgentsPage from './AgentsPage.vue'
import LoopsPage from './LoopsPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { EndedSession, PageData } from '@/types/dashboard'

const props = { shell: fixture.shell, agents: fixture.agents } as unknown as PageData

const ended = (id: string, title: string): EndedSession => ({
  id, title, cwd: '~/Projects/app', branch: null, ended: new Date().toISOString(), tokensTotal: 900, turns: 3,
  lastReply: '', resumeCommand: `claude --resume ${id}`, cursor: new Date().toISOString(),
})

let fetchMock: ReturnType<typeof vi.fn>

beforeEach(() => {
  fetchMock = vi.fn(async (url: string) => {
    const q = new URL(url, 'http://x').searchParams.get('q')
    const items = q ? [ended('e2', 'Pull request review')] : [ended('e1', 'Root cause investigation'), ended('e2', 'Pull request review')]
    return new Response(JSON.stringify({ items, nextCursor: null }), { status: 200 })
  })
  vi.stubGlobal('fetch', fetchMock)
})
afterEach(() => vi.unstubAllGlobals())

describe('AgentsPage', () => {
  it('groups sessions apart from background jobs and filters to the ones waiting on you', async () => {
    const page = mount(AgentsPage, { props })

    expect(page.text()).toContain('Sessions')
    await page.findAll('[role="radio"]').find((b) => b.text().startsWith('Waiting on you'))!.trigger('click')

    const names = page.findAll('tbody tr td:first-child .font-mono').map((n) => n.text())
    expect(names.length).toBeGreaterThan(0)
    expect(names.every((name) => props.agents.find((a) => a.name === name)?.status === 'blocked')).toBe(true)
  })

  it('shows the first page of ended sessions, loads more on request and searches on the server', async () => {
    vi.useFakeTimers()
    const page = mount(AgentsPage, { props })
    await flushPromises()

    expect(page.text()).toContain('Root cause investigation')
    expect(page.text()).toContain('Resume')
    expect(page.findAll('button').some((b) => b.text() === 'Load more')).toBe(false)

    await page.find('input[type="search"]').setValue('review')
    vi.advanceTimersByTime(300)
    await flushPromises()

    expect(fetchMock).toHaveBeenLastCalledWith(expect.stringContaining('q=review'), expect.anything())
    expect(page.text()).not.toContain('Root cause investigation')
    vi.useRealTimers()
  })

  it('goes back from a transcript to the agent it was opened from', async () => {
    const page = mount(AgentsPage, { props, attachTo: document.body })
    const agent = props.agents.find((a) => a.kind === 'yours')!

    await page.findAll('tbody tr').find((r) => r.text().includes(agent.name))!.trigger('click')
    await page.findAll('[role="dialog"] button').find((b) => b.text().includes('Transcript'))!.trigger('click')
    expect(page.find('[role="dialog"]').text()).toContain('Transcript')

    await page.findAll('[role="dialog"] button').find((b) => b.text().includes('Back'))!.trigger('click')

    expect(page.find('[role="dialog"]').text()).toContain('Summarise')
    page.unmount()
  })
})

describe('Show terminal', () => {
  it('is disabled with the reason when the agent has no terminal to show', async () => {
    const agent = { ...props.agents[0], terminalUnavailable: "Background jobs don't run in a terminal window" }
    const page = mount(AgentsPage, { props: { ...props, agents: [agent] }, attachTo: document.body })

    await page.findAll('tbody tr').find((r) => r.text().includes(agent.name))!.trigger('click')
    const button = page.findAll('[role="dialog"] button').find((b) => b.text().includes('Show terminal'))!

    expect(button.attributes('disabled')).toBeDefined()
    page.unmount()
  })
})

describe('renaming', () => {
  it('sends the new name to the session and shows the model', async () => {
    const agent = { ...props.agents.find((a) => a.kind === 'yours')!, terminalUnavailable: null }
    const page = mount(AgentsPage, { props: { ...props, agents: [agent] }, attachTo: document.body })
    await page.findAll('tbody tr').find((r) => r.text().includes(agent.name))!.trigger('click')
    const dialog = () => page.find('[role="dialog"]')
    expect(dialog().text()).toContain(agent.model)

    await dialog().find('button[aria-label="Rename agent"]').trigger('click')
    await dialog().find('input[aria-label="Agent name"]').setValue('Payments work')
    await dialog().findAll('button').find((b) => b.text() === 'Save')!.trigger('click')
    await flushPromises()

    expect(fetchMock).toHaveBeenCalledWith(`/api/agents/${agent.id}/rename`, expect.objectContaining({ method: 'POST', body: JSON.stringify({ name: 'Payments work' }) }))
    page.unmount()
  })
})

describe('deep links', () => {
  it('opens the agent a notification points at, then tidies the address', async () => {
    const agent = props.agents.find((a) => a.kind === 'yours')!
    history.replaceState(null, '', `/agents?agent=${agent.id}`)

    const page = mount(AgentsPage, { props, attachTo: document.body })
    await page.vm.$nextTick()

    expect(page.find('[role="dialog"]').text()).toContain(agent.name)
    expect(location.search).toBe('')
    page.unmount()
  })
})

describe('LoopsPage', () => {
  it('lists every loop across sessions and filters by kind', async () => {
    const page = mount(LoopsPage, { props })
    const loops = props.agents.flatMap((a) => a.loops)

    expect(page.findAll('tbody tr').length).toBe(loops.length)
    await page.findAll('[role="radio"]').find((b) => b.text().startsWith('Cron'))!.trigger('click')

    expect(page.findAll('tbody tr').length).toBe(loops.filter((l) => l.kind === 'cron').length)
  })
})
