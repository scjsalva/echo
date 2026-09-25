import { timeUntil } from './format'
import type { AgentLoop } from '@/types/dashboard'

export const loopKind: Record<AgentLoop['kind'], string> = { monitor: 'Monitor', wakeup: 'Self-paced loop', cron: 'Cron' }

function duration(seconds: number): string {
  return seconds % 3600 === 0 ? `${seconds / 3600}h` : seconds % 60 === 0 ? `${seconds / 60}m` : `${seconds}s`
}

/** Events per hour since the loop started, measured over at least 15 minutes so new loops don't spike. */
export function eventsPerHour(loop: AgentLoop, now: number): number {
  const hours = Math.max((now - Date.parse(loop.startedAt)) / 3_600_000, 0.25)
  return Math.round((loop.events / hours) * 10) / 10
}

/** When a loop runs next and how much it has done, e.g. "every 20m · next in 4m · 3 runs". */
export function describeLoop(loop: AgentLoop, now: number): string {
  const count = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`
  switch (loop.kind) {
    case 'monitor':
      return [count(loop.events, 'event'), loop.expiresAt ? `stops ${timeUntil(loop.expiresAt, now)}` : 'no time limit'].join(' · ')
    case 'wakeup':
      return [loop.every && `every ${duration(loop.every)}`, loop.nextRunAt && `next ${timeUntil(loop.nextRunAt, now)}`, count(loop.events, 'run')]
        .filter(Boolean)
        .join(' · ')
    case 'cron':
      return [loop.cron, loop.nextRunAt && `next ${timeUntil(loop.nextRunAt, now)}`].filter(Boolean).join(' · ')
  }
}
