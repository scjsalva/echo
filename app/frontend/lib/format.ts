const MINUTE = 60_000
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

export function timeAgo(iso: string, now: number = Date.now()): string {
  const diff = Math.max(0, now - Date.parse(iso))
  if (diff < MINUTE) return `${Math.round(diff / 1000)}s`
  if (diff < HOUR) return `${Math.round(diff / MINUTE)}m`
  if (diff < 2 * DAY) return `${Math.round(diff / HOUR)}h`
  return `${Math.round(diff / DAY)}d`
}

export function timeUntil(iso: string, now: number = Date.now()): string {
  const diff = Date.parse(iso) - now
  return diff <= 0 ? 'now' : `in ${timeAgo(new Date(now - diff).toISOString(), now)}`
}

export function formatTokens(n: number): string {
  if (n >= 1e6) return `${(n / 1e6).toFixed(1)}M`
  if (n >= 1e3) return `${Math.round(n / 1e3)}k`
  return String(n)
}

/** Splits a count into its zero-padding and significant digits, e.g. 7 → ['00', '7']. */
export function padCount(n: number, width = 3): [string, string] {
  const digits = String(n)
  return ['0'.repeat(Math.max(0, width - digits.length)), digits]
}

export function initials(name: string): string {
  const words = name.trim().split(/\s+/)
  return (words.length > 1 ? words[0][0] + words[1][0] : name.slice(0, 2)).toUpperCase()
}
