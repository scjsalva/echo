import { afterEach, describe, expect, it, vi } from 'vitest'
import { request } from './api'

afterEach(() => vi.unstubAllGlobals())

describe('request', () => {
  it('reads JSON, and accepts replies with no body', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ ok: true }), { status: 200 })))
    expect(await request('GET', '/x')).toEqual({ ok: true })

    vi.stubGlobal('fetch', vi.fn(async () => new Response(null, { status: 202 })))
    expect(await request('PATCH', '/api/health?source=github')).toBeUndefined()
  })
})
