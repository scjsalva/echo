import { describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import OverviewPage from './OverviewPage.vue'
import fixture from '@/test/overview.fixture.json'
import type { OverviewProps } from '@/types/dashboard'

// Built from test/fixtures/files/dashboard_sample.yml. Regenerate with:
// bin/rails runner 'require "./test/support/sample_data"; puts JSON.pretty_generate(ApplicationController.new.send(:camelize, Dashboard.new(data: SampleData.load, dismissed_keys: []).overview_props))' > app/frontend/test/overview.fixture.json
const props = fixture as unknown as OverviewProps

function mountPage() {
  return mount(OverviewPage, { props, attachTo: document.body })
}

describe('OverviewPage', () => {
  it('shows the stats, waiting items and review queue', () => {
    const page = mountPage()

    expect(page.text()).toContain('Waiting on you')
    expect(page.text()).toContain('Review queue')
    expect(page.text()).toContain(props.reviewQueue.items[0].title)
    page.unmount()
  })

  it('opens a waiting item in a panel with a dismiss option instead of linking out', async () => {
    const page = mountPage()
    const item = props.waiting.items.find((w) => w.source === 'github')!

    await page.findAll('button').find((b) => b.text().includes(item.title))!.trigger('click')

    const drawer = page.find('[role="dialog"]')
    expect(drawer.exists()).toBe(true)
    expect(drawer.text()).toContain('Dismiss')
    expect(drawer.text()).toContain(item.clears)
    page.unmount()
  })

  it('opens a PR from the review queue with GitHub and Review actions', async () => {
    const page = mountPage()
    const pr = props.reviewQueue.items[0]

    await page.findAll('button').filter((b) => b.text().includes(pr.title)).at(-1)!.trigger('click')

    const drawer = page.find('[role="dialog"]')
    expect(drawer.text()).toContain(pr.description ?? 'No description.')
    expect(drawer.find(`a[href="${pr.url}"]`).exists()).toBe(true)
    expect(drawer.find(`a[href="/reviews/${pr.fullName}/${pr.number}"]`).text()).toContain('Review')
    page.unmount()
  })

  it('shows empty states and zero counts when nothing is connected', () => {
    const empty: OverviewProps = {
      ...props,
      shell: { ...props.shell, waitingCount: 0, unreadCount: 0, missingConnections: ['GitHub', 'Jira'] },
      stats: { agents: { agents: 0, busy: 0, tokensUsed: 0 }, github: { team: 0, mine: 0, watching: 0 }, jira: { open: 0, done: 0 } },
      waiting: { items: [], total: 0 },
      reviewQueue: { items: [], total: 0 },
      agents: [],
      pullRequests: [],
      githubNotifications: [],
      jiraTickets: [],
      jiraNotifications: [],
    }
    const page = mount(OverviewPage, { props: empty })

    expect(page.text()).toContain("GitHub and Jira aren't connected yet.")
    expect(page.text()).not.toContain('Waiting on you')
    expect(page.text()).toContain('Nothing is ready for review.')
    expect(page.text()).toContain('No Claude Code sessions running.')
    expect(page.text()).toContain('000')
    page.unmount()
  })

  it('closes the panel with Escape', async () => {
    const page = mountPage()
    await page.findAll('button').find((b) => b.text().includes(props.agents[0].name))!.trigger('click')
    expect(page.find('[role="dialog"]').exists()).toBe(true)

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }))
    await page.vm.$nextTick()

    expect(page.find('[role="dialog"]').exists()).toBe(false)
    page.unmount()
  })

  it("opens the ticket named in a PR's title even when Echo doesn't sync it", async () => {
    const pr = { ...props.reviewQueue.items[0], jiraKey: 'APP-99999' }
    const teammates = { ...props.jiraTickets[0], key: 'APP-99999', title: "A teammate's ticket" }
    vi.stubGlobal('fetch', vi.fn(async (url: string) => new Response(JSON.stringify(url.startsWith('/api/jira/search') ? { items: [teammates], more: false } : { alerts: [] }), { status: 200 })))
    const page = mount(OverviewPage, { props: { ...props, reviewQueue: { ...props.reviewQueue, items: [pr] }, pullRequests: [pr] }, attachTo: document.body })

    await page.findAll('button').filter((b) => b.text().includes(pr.title)).at(-1)!.trigger('click')
    await page.findAll('[role="dialog"] button').find((b) => b.text() === 'APP-99999')!.trigger('click')
    await flushPromises()

    expect(page.find('[role="dialog"]').text()).toContain("A teammate's ticket")
    page.unmount()
    vi.unstubAllGlobals()
  })
})
