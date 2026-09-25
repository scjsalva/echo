import { describe, expect, it } from 'vitest'
import { describeLoop, eventsPerHour } from './loops'
import type { AgentLoop } from '@/types/dashboard'

const now = Date.parse('2026-09-25T12:00:00Z')
const inMinutes = (m: number) => new Date(now + m * 60_000).toISOString()
const base = { id: 'x', description: 'd', startedAt: inMinutes(-30), events: 0, lastEventAt: null }

describe('describeLoop', () => {
  it('describes monitors by events and time limit', () => {
    expect(describeLoop({ ...base, kind: 'monitor', events: 1, expiresAt: inMinutes(10) } as AgentLoop, now)).toBe('1 event · stops in 10m')
    expect(describeLoop({ ...base, kind: 'monitor', events: 3, expiresAt: null } as AgentLoop, now)).toBe('3 events · no time limit')
  })

  it('describes self-paced loops by interval, next run and runs', () => {
    expect(describeLoop({ ...base, kind: 'wakeup', every: 1200, nextRunAt: inMinutes(4), events: 2 } as AgentLoop, now)).toBe(
      'every 20m · next in 4m · 2 runs',
    )
  })

  it('rates events per hour, measuring new loops over at least 15 minutes', () => {
    expect(eventsPerHour({ ...base, kind: 'monitor', startedAt: inMinutes(-120), events: 6 } as AgentLoop, now)).toBe(3)
    expect(eventsPerHour({ ...base, kind: 'monitor', startedAt: inMinutes(-1), events: 2 } as AgentLoop, now)).toBe(8)
  })

  it('describes cron loops by expression and next run', () => {
    expect(describeLoop({ ...base, kind: 'cron', cron: '*/5 * * * *', nextRunAt: inMinutes(3) } as AgentLoop, now)).toBe('*/5 * * * * · next in 3m')
  })
})
