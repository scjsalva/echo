import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
// The theme code reads the system preference when it loads; jsdom doesn't have it.
vi.hoisted(() => {
  window.matchMedia ??= ((query: string) => ({ matches: false, media: query, addEventListener() {}, removeEventListener() {} })) as never
  window.scrollTo = () => undefined
})
import SettingsPage from './SettingsPage.vue'
import fixture from '@/test/overview.fixture.json'

const props = {
  shell: fixture.shell,
  connections: [],
  timeZone: { preference: 'auto', detected: 'UTC', current: 'UTC', options: [] },
  notifications: {
    desktop: true, settingsHint: 'System Settings', available: true, scope: 'waiting', sound: 'Ping', sounds: ['Ping', 'Pop'],
    types: [], enabledTypes: [], reminderMinutes: 30, reminderOptions: [0, 30],
    workingHours: { enabled: false, days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00', timeZone: 'UTC' },
  },
  github: { repos: [], reposChosen: false, team: [], knownRepos: [], knownPeople: [], localRepos: [] },
  claude: { reviewLimit: 3, reviewLimitOptions: [1, 2, 3], skills: [], context: { global: [], repos: [], extras: [] } },
}

afterEach(() => {
  vi.unstubAllGlobals()
  vi.restoreAllMocks()
  history.replaceState(null, '', '/')
})

const nav = (page: ReturnType<typeof mount>, label: string) =>
  page.findAll('nav[aria-label="Settings sections"] button').find((b) => b.text().includes(label))!

describe('SettingsPage', () => {
  it('saves and cancels one section at a time, and asks before leaving one with changes', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ alerts: [], version: 0 }), { status: 200 })))
    history.replaceState(null, '', '/settings#notifications')
    const page = mount(SettingsPage, { props: props as never, attachTo: document.body })
    await flushPromises()

    await page.find('select[aria-label="Notification sound"]').setValue('Pop')
    expect(page.find('[aria-label="Unsaved changes in Notifications"]').exists()).toBe(true)
    expect(nav(page, 'Notifications').find('[aria-label="Unsaved changes"]').exists()).toBe(true)

    vi.spyOn(window, 'confirm').mockReturnValueOnce(false)
    await nav(page, 'GitHub').trigger('click')
    expect(nav(page, 'Notifications').attributes('aria-current')).toBe('page')

    vi.spyOn(window, 'confirm').mockReturnValueOnce(true)
    await nav(page, 'GitHub').trigger('click')
    await flushPromises()
    expect(nav(page, 'GitHub').attributes('aria-current')).toBe('page')
    expect((page.find('select[aria-label="Notification sound"]').element as HTMLSelectElement).value).toBe('Ping')
    expect(page.find('[aria-label^="Unsaved changes in"]').exists()).toBe(false)
    page.unmount()
  })
})
