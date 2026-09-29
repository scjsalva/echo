import { describe, expect, it } from 'vitest'
import { wakeProgress } from './wakeProgress'

const since = Date.parse('2026-09-29T05:44:00Z')
const sync = (source: string, fields: Record<string, unknown> = {}) => ({ source, label: source, connected: true, lastSuccessAt: '2026-09-29T05:12:00Z', ...fields })

describe('wakeProgress', () => {
  it('counts only runs since the pause, and only connected syncs', () => {
    const { rows, allDone } = wakeProgress(
      [
        sync('github', { lastSuccessAt: '2026-09-29T05:45:00Z' }),
        sync('jira', { lastErrorAt: '2026-09-29T05:45:10Z', lastError: 'acli took longer than 30s' }),
        sync('notify', { runningSince: '2026-09-29T05:45:20Z' }),
        sync('other', { connected: false }),
      ],
      since,
    )
    expect(rows.map((r) => [r.source, r.state, r.error])).toEqual([
      ['github', 'done', null],
      ['jira', 'failed', 'acli took longer than 30s'],
      ['notify', 'running', null],
    ])
    expect(allDone).toBe(false)
  })

  it('is done once every connected sync has succeeded since', () => {
    expect(wakeProgress([sync('github', { lastSuccessAt: '2026-09-29T05:45:00Z' })], since).allDone).toBe(true)
    expect(wakeProgress([sync('github')], since).rows[0].state).toBe('waiting')
  })
})
