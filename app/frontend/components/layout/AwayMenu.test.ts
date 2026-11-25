import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AwayBanner from './AwayBanner.vue'
import AwayMenu from './AwayMenu.vue'

afterEach(() => vi.unstubAllGlobals())

const ok = () => vi.fn(async () => new Response('{}', { status: 200 }))

describe('Away', () => {
  it('goes away for the rest of today, showing when you would be back', async () => {
    const fetch = ok()
    vi.stubGlobal('fetch', fetch)
    const menu = mount(AwayMenu, { props: { away: { until: null, restOfToday: '2026-11-30T08:00:00Z' }, linkClass: '' } })

    await menu.find('button[aria-label="Away"]').trigger('click')
    const today = menu.findAll('[role="dialog"] button').find((b) => b.text().includes('Rest of today'))!
    expect(today.text()).toContain('Back Mon 30 Nov')
    await today.trigger('click')
    await flushPromises()

    expect(fetch).toHaveBeenCalledWith('/api/away', expect.objectContaining({ method: 'PATCH', body: JSON.stringify({ choice: 'today' }) }))
    expect(menu.find('[role="dialog"]').exists()).toBe(false)
  })

  it("says when you're back, and ends it early", async () => {
    const fetch = ok()
    vi.stubGlobal('fetch', fetch)
    const banner = mount(AwayBanner, { props: { until: '2026-11-30T08:00:00Z' } })

    expect(banner.text()).toContain('Away until Mon 30 Nov')
    await banner.find('button').trigger('click')

    expect(fetch).toHaveBeenCalledWith('/api/away', expect.objectContaining({ method: 'DELETE' }))
  })
})
