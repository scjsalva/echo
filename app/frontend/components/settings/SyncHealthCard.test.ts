import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import SyncHealthCard from './SyncHealthCard.vue'

const ago = (minutes: number) => new Date(Date.now() - minutes * 60_000).toISOString()
const sync = (fields: object) => ({
  source: 'github', label: 'GitHub sync', status: 'ok', lastSuccessAt: ago(2), lastAttemptAt: ago(2), lastError: null, lastErrorAt: null,
  failures: 0, runningSince: null, lastSkippedAt: null, ...fields,
})

afterEach(() => vi.unstubAllGlobals())

async function card(syncs: object[]) {
  const health = { scheduler: { lastRunAt: ago(0), stalled: false, coveringSince: null }, syncs }
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify(health), { status: 200 })))
  const page = mount(SyncHealthCard)
  await flushPromises()
  return page.text()
}

describe('SyncHealthCard', () => {
  it('says one clear thing per sync', async () => {
    expect(await card([sync({})])).toContain('Synced 2m ago.')
    expect(await card([sync({ runningSince: ago(0) })])).toContain('Syncing now…')

    const failing = await card([sync({ status: 'failing', lastSuccessAt: ago(120), failures: 2, lastErrorAt: ago(37), lastError: 'gh took longer than 60s' })])
    expect(failing).toContain('The last 2 tries failed, most recently 37m ago: gh took longer than 60s. It keeps retrying every minute.')
    expect(failing).not.toContain('Syncing now')

    const stuck = await card([sync({ status: 'not_starting', lastSuccessAt: ago(120), lastAttemptAt: ago(37), failures: 2, lastError: 'x' })])
    expect(stuck).toContain("It's queued every minute but hasn't run since 37m ago. Try Sync now")
    expect(stuck).not.toContain('tries failed')
  })
})
