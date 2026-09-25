import { ref, watch } from 'vue'

export type ThemePreference = 'system' | 'light' | 'dark'

const STORAGE_KEY = 'echo.theme'
const systemDark = matchMedia('(prefers-color-scheme: dark)')

function readPreference(): ThemePreference {
  try {
    const saved = localStorage.getItem(STORAGE_KEY)
    return saved === 'light' || saved === 'dark' ? saved : 'system'
  } catch {
    return 'system'
  }
}

const preference = ref<ThemePreference>(readPreference())

function apply() {
  const dark = preference.value === 'dark' || (preference.value === 'system' && systemDark.matches)
  document.documentElement.dataset.theme = dark ? 'dark' : 'light'
}

watch(preference, (value) => {
  try {
    localStorage.setItem(STORAGE_KEY, value)
  } catch {
    // Storage can be unavailable (private mode); the choice still applies for this visit.
  }
  apply()
})
systemDark.addEventListener('change', apply)

export function useTheme() {
  return { preference }
}
