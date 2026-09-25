import { ref, watch } from 'vue'

/** A boolean remembered in localStorage, e.g. whether a section is expanded. */
export function usePersistentFlag(key: string, initial: boolean) {
  const storageKey = `echo.${key}`
  let stored: string | null = null
  try {
    stored = localStorage.getItem(storageKey)
  } catch {
    // Unavailable storage just means the default is used.
  }

  const flag = ref(stored === null ? initial : stored === 'true')
  watch(flag, (value) => {
    try {
      localStorage.setItem(storageKey, String(value))
    } catch {
      // Same as above: the choice still applies for this visit.
    }
  })
  return flag
}
