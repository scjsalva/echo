import { ref, watch, type Ref } from 'vue'

/**
 * A draggable column width, remembered in this browser. Keeps between `min`
 * pixels and `maxShare` of the container.
 */
export function useSplitWidth(key: string, container: Ref<HTMLElement | undefined>, { initial = 360, min = 280, maxShare = 0.6 } = {}) {
  const storageKey = `echo.${key}`
  let saved = NaN
  try {
    saved = Number(localStorage.getItem(storageKey))
  } catch {
    // Unavailable storage just means the default width.
  }
  const width = ref(Number.isFinite(saved) && saved > 0 ? saved : initial)

  const clamp = (value: number) => {
    const max = (container.value?.clientWidth ?? window.innerWidth) * maxShare
    return Math.round(Math.min(Math.max(value, min), Math.max(max, min)))
  }

  watch(width, (value) => {
    try {
      localStorage.setItem(storageKey, String(value))
    } catch {
      // Same as above: the width still applies for this visit.
    }
  })

  function startDrag(event: PointerEvent) {
    const left = container.value?.getBoundingClientRect().left ?? 0
    const handle = event.currentTarget as HTMLElement
    handle.setPointerCapture(event.pointerId)
    const move = (e: PointerEvent) => (width.value = clamp(e.clientX - left))
    const stop = () => {
      handle.removeEventListener('pointermove', move)
      handle.removeEventListener('pointerup', stop)
      document.body.style.removeProperty('user-select')
    }
    document.body.style.userSelect = 'none'
    handle.addEventListener('pointermove', move)
    handle.addEventListener('pointerup', stop)
  }

  const nudge = (step: number) => (width.value = clamp(width.value + step))
  const reset = () => (width.value = clamp(initial))

  return { width, startDrag, nudge, reset }
}
