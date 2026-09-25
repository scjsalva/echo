import { onScopeDispose, ref } from 'vue'
import { request } from '@/lib/api'

export interface Alert {
  id: string
  source: string
  title: string
  subtitle: string
  message: string
  /** Opens the item itself: the agent, the ticket or the PR. */
  url?: string
}

const LIMIT = 3
const SHOW_FOR_MS = 30_000
const CHECK_MS = 10_000

/** A short two-note chime, for when a sound file can't be played. */
function chime() {
  try {
    const audio = new AudioContext()
    ;[880, 1175].forEach((frequency, i) => {
      const oscillator = audio.createOscillator()
      const gain = audio.createGain()
      const start = audio.currentTime + i * 0.12
      oscillator.frequency.value = frequency
      gain.gain.setValueAtTime(0.0001, start)
      gain.gain.exponentialRampToValueAtTime(0.2, start + 0.01)
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.35)
      oscillator.connect(gain).connect(audio.destination)
      oscillator.start(start)
      oscillator.stop(start + 0.4)
    })
  } catch {
    // No audio available; the alert still shows.
  }
}

function play(sound: string) {
  new Audio(`/sounds/${sound}`).play().catch(chime)
}

/**
 * In-app alerts for things that just arrived, on whatever Echo page is open.
 * The first check only learns what's already there, so opening a page is quiet.
 * With several Echo tabs open, only the one you're looking at shows an alert.
 */
export function useAlerts() {
  const alerts = ref<Alert[]>([])
  let seen: Set<string> | null = null
  const tabs = typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel('echo-alerts')
  tabs?.addEventListener('message', (event: MessageEvent<string[]>) => event.data.forEach((id) => seen?.add(id)))

  function dismiss(id: string) {
    alerts.value = alerts.value.filter((a) => a.id !== id)
  }

  async function check() {
    const response = await request<{ alerts: Alert[]; show: boolean; sound: string | null }>('GET', '/api/alerts').catch(() => null)
    if (!response) return
    const fresh = seen ? response.alerts.filter((a) => !seen!.has(a.id)) : []
    seen = new Set(response.alerts.map((a) => a.id))
    // With OS notifications on they cover it, so the page stays quiet.
    if (!response.show || !fresh.length || document.visibilityState !== 'visible') return

    tabs?.postMessage(fresh.map((a) => a.id))
    for (const alert of fresh) {
      alerts.value = [alert, ...alerts.value].slice(0, LIMIT)
      setTimeout(() => dismiss(alert.id), SHOW_FOR_MS)
    }
    if (response.sound) play(response.sound)
  }

  check()
  const timer = setInterval(check, CHECK_MS)
  onScopeDispose(() => {
    clearInterval(timer)
    tabs?.close()
  })

  return { alerts, dismiss }
}
