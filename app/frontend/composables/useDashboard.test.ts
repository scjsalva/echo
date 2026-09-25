import { afterEach, describe, expect, it, vi } from 'vitest'
import { defineComponent, h } from 'vue'
import { flushPromises, mount } from '@vue/test-utils'
import { provideDashboard } from './useDashboard'
import type { PageData } from '@/types/dashboard'

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

function mountWith(live: boolean, versions: number[]) {
  const calls: string[] = []
  vi.stubGlobal('fetch', vi.fn(async (url: string) => {
    calls.push(url)
    const body = url === '/api/changes' ? { version: versions.shift() ?? 0 } : { shell: { live }, agents: [] }
    return new Response(JSON.stringify(body), { status: 200 })
  }))
  mount(defineComponent(() => {
    provideDashboard({ shell: { live } as PageData['shell'], agents: [] }, '/api/dashboard')
    return () => h('div')
  }))
  return calls
}

describe('live refresh', () => {
  it('refreshes as soon as the change counter moves', async () => {
    vi.useFakeTimers()
    const calls = mountWith(true, [1, 1, 2])

    for (let i = 0; i < 3; i++) {
      vi.advanceTimersByTime(3000)
      await flushPromises()
    }

    expect(calls.filter((c) => c === '/api/dashboard')).toHaveLength(1)
  })

  it('does not poll for changes without hooks', async () => {
    vi.useFakeTimers()
    const calls = mountWith(false, [1, 2])

    vi.advanceTimersByTime(9000)
    await flushPromises()

    expect(calls).not.toContain('/api/changes')
  })
})
