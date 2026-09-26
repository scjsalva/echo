import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { defineComponent, h } from 'vue'
import NotificationSettings from './NotificationSettings.vue'
import { provideSettingsDraft } from '@/composables/useSettingsDraft'
import type { NotificationSettings as Settings } from '@/types/dashboard'

const settings: Settings = {
  desktop: true, settingsHint: 'System Settings', available: true, scope: 'waiting', sound: 'Ping', sounds: ['Ping', 'Pop'],
  types: [], enabledTypes: [], reminderMinutes: 30, reminderOptions: [0, 30],
  workingHours: { enabled: false, days: [1, 2, 3, 4, 5], start: '09:00', end: '17:00', timeZone: 'UTC' },
}

function mountWithDraft() {
  let draft!: ReturnType<typeof provideSettingsDraft>
  const Host = defineComponent({ setup: () => ((draft = provideSettingsDraft()), () => h(NotificationSettings, { settings })) })
  return { page: mount(Host), draft: () => draft }
}

afterEach(() => vi.unstubAllGlobals())

describe('NotificationSettings', () => {
  it("sends nothing until Save, and Cancel puts it back", async () => {
    const fetchMock = vi.fn(async () => new Response(null, { status: 204 }))
    vi.stubGlobal('fetch', fetchMock)
    const { page, draft } = mountWithDraft()

    await page.find('select[aria-label="Notification sound"]').setValue('Pop')
    await page.find('button[aria-label="Working hours"]').trigger('click')
    expect(fetchMock).not.toHaveBeenCalled()
    expect(draft().dirty.value).toBe(true)
    expect(page.find('[aria-label="Working days"]').exists()).toBe(true)

    draft().cancel()
    await flushPromises()
    expect((page.find('select[aria-label="Notification sound"]').element as HTMLSelectElement).value).toBe('Ping')
    expect(page.find('[aria-label="Working days"]').exists()).toBe(false)
    expect(draft().dirty.value).toBe(false)

    await page.find('select[aria-label="Notification sound"]').setValue('Pop')
    await draft().save()
    expect(fetchMock).toHaveBeenCalledTimes(1)
    expect(JSON.parse((fetchMock.mock.calls[0] as unknown as [string, RequestInit])[1].body as string)).toEqual({ notify_sound: 'Pop' })
    expect(draft().dirty.value).toBe(false)
  })

  it('shows the times beside the days, and hides both when working hours are off', async () => {
    vi.stubGlobal('fetch', vi.fn())
    const { page } = mountWithDraft()

    await page.find('button[aria-label="Working hours"]').trigger('click')
    const controls = page.find('div[aria-label="Working hours"]')
    expect(controls.find('[aria-label="Working days"]').exists()).toBe(true)
    expect(controls.find('input[aria-label="Start"]').exists()).toBe(true)

    await page.find('button[aria-label="Working hours"]').trigger('click')
    expect(page.find('input[aria-label="Start"]').exists()).toBe(false)
  })
})
