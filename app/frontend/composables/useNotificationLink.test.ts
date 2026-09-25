import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AppShell from '@/components/layout/AppShell.vue'
import { drawerTarget } from './useNotificationLink'
import fixture from '@/test/overview.fixture.json'
import type { OverviewProps } from '@/types/dashboard'

const overview = fixture as unknown as OverviewProps
const pr = overview.pullRequests[0]

afterEach(() => {
  vi.unstubAllGlobals()
  history.replaceState(null, '', '/')
})

describe('drawerTarget', () => {
  it('turns item links into drawers, and leaves page links alone', () => {
    expect(drawerTarget('http://localhost:4848/github?pr=acme%2Fweb%235&notification=g1')).toEqual({ type: 'pullRequest', key: 'acme/web#5', notificationId: 'g1' })
    expect(drawerTarget('/jira?ticket=APP-1')).toEqual({ type: 'ticket', key: 'APP-1', notificationId: undefined })
    expect(drawerTarget('/agents?agent=a1')).toEqual({ type: 'agent', id: 'a1' })
    expect(drawerTarget('/github')).toBeNull()
    // Exactly what the macOS notifier hands the tab, keys with "/" and "#" still encoded.
    const fragment = '%2Fgithub%3Fnotification%3Dgithub%2Dready%2Dacme%252Fweb%252327019%2D1%26pr%3Dacme%252Fweb%252327019'
    expect(drawerTarget(decodeURIComponent(fragment))).toEqual({ type: 'pullRequest', key: 'acme/web#27019', notificationId: 'github-ready-acme/web#27019-1' })
  })
})

describe('opening a notification over any page', () => {
  it('opens the PR in a drawer without leaving the page', async () => {
    vi.stubGlobal('fetch', vi.fn(async (url: string) => new Response(JSON.stringify(url === '/api/dashboard' ? overview : { alerts: [], show: false, sound: null }), { status: 200 })))
    history.replaceState(null, '', `/settings#echo-open=${encodeURIComponent(`/github?pr=${encodeURIComponent(pr.key)}`)}`)

    const page = mount(AppShell, { props: { shell: overview.shell, showFirstRun: false }, slots: { default: '<p>Settings here</p>' }, attachTo: document.body })
    await flushPromises()

    expect(location.pathname).toBe('/settings')
    expect(location.hash).toBe('')
    expect(page.text()).toContain('Settings here')
    expect(document.body.querySelector('[role="dialog"]')?.textContent).toContain(pr.title)
    page.unmount()
  })
})
