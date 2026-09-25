import { afterEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import AlertStack from './AlertStack.vue'

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

const alert = (id: string) => ({ id, source: 'agent', title: 'Waiting on you', subtitle: 'Agent', message: `Allow Bash(${id})` })

describe('AlertStack', () => {
  it('stays quiet about what was already there and shows what arrives later', async () => {
    vi.useFakeTimers()
    const responses = [[alert('old')], [alert('old'), alert('new')]]
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ alerts: responses.shift() ?? [], show: true, sound: null }), { status: 200 })))

    const stack = mount(AlertStack)
    await flushPromises()
    expect(stack.text()).toBe('')

    vi.advanceTimersByTime(10_000)
    await flushPromises()

    expect(stack.text()).toContain('Allow Bash(new)')
    expect(stack.text()).not.toContain('Allow Bash(old)')
  })

  it('keeps an alert up for 30 seconds and plays the in-app sound', async () => {
    vi.useFakeTimers()
    const played: string[] = []
    vi.stubGlobal('Audio', class { constructor(public src: string) { played.push(src) } play() { return Promise.resolve() } })
    const responses = [[], [alert('new')]]
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ alerts: responses.shift() ?? [alert('new')], show: true, sound: 'Glass' }), { status: 200 })))

    const stack = mount(AlertStack)
    await flushPromises()
    vi.advanceTimersByTime(10_000)
    await flushPromises()
    expect(played).toEqual(['/sounds/Glass'])

    vi.advanceTimersByTime(29_000)
    await flushPromises()
    expect(stack.text()).toContain('Allow Bash(new)')
    vi.advanceTimersByTime(2_000)
    await flushPromises()
    expect(stack.text()).not.toContain('Allow Bash(new)')
  })

  it('stays quiet while OS notifications are on', async () => {
    vi.useFakeTimers()
    const responses = [[], [alert('new')]]
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ alerts: responses.shift() ?? [alert('new')], show: false, sound: 'Glass' }), { status: 200 })))

    const stack = mount(AlertStack)
    await flushPromises()
    vi.advanceTimersByTime(10_000)
    await flushPromises()

    expect(stack.text()).toBe('')
  })
})
