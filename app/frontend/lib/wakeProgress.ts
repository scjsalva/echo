export interface WakeSync {
  source: string
  label: string
  connected: boolean
  lastSuccessAt: string | null
  lastErrorAt?: string | null
  lastError?: string | null
  runningSince?: string | null
}

export type WakeState = 'done' | 'failed' | 'running' | 'waiting'

/** How each connected sync is getting on since `since` (the wake, or Echo's restart). */
export function wakeProgress(syncs: WakeSync[], since: number) {
  const after = (at?: string | null) => Boolean(at && Date.parse(at) >= since)
  const rows = syncs
    .filter((s) => s.connected)
    .map((s) => {
      const state: WakeState = after(s.lastSuccessAt) ? 'done' : after(s.lastErrorAt) ? 'failed' : s.runningSince ? 'running' : 'waiting'
      return { source: s.source, label: s.label, state, error: state === 'failed' ? (s.lastError ?? null) : null }
    })
  return { rows, allDone: rows.every((r) => r.state === 'done') }
}
