import { computed, inject, provide, ref, shallowRef, toRaw, type InjectionKey, type Ref } from 'vue'

/**
 * Settings changes wait here until Save. Each change is staged under a key, so
 * changing the same setting twice keeps only the last one; Save sends them in
 * order, and Cancel puts every setting back to what was last saved.
 */
interface Draft {
  dirty: Ref<boolean>
  saving: Ref<boolean>
  stage: (key: string, apply: () => Promise<unknown>) => void
  save: () => Promise<boolean>
  cancel: () => void
  onCancel: (fn: () => void) => void
  onSaved: (fn: () => void) => void
}

const DraftKey: InjectionKey<Draft> = Symbol('settings-draft')

export function provideSettingsDraft(): Draft {
  const changes = shallowRef(new Map<string, () => Promise<unknown>>())
  const saving = ref(false)
  const cancelHooks = new Set<() => void>()
  const savedHooks = new Set<() => void>()

  const draft: Draft = {
    dirty: computed(() => changes.value.size > 0),
    saving,
    stage(key, apply) {
      const next = new Map(changes.value)
      next.delete(key)
      next.set(key, apply)
      changes.value = next
    },
    // Stops at the first change that fails, keeping it and the rest staged.
    async save() {
      saving.value = true
      try {
        for (const [key, apply] of changes.value) {
          await apply()
          const next = new Map(changes.value)
          next.delete(key)
          changes.value = next
        }
        savedHooks.forEach((fn) => fn())
        return true
      } finally {
        saving.value = false
      }
    },
    cancel() {
      changes.value = new Map()
      cancelHooks.forEach((fn) => fn())
    },
    onCancel: (fn) => cancelHooks.add(fn),
    onSaved: (fn) => savedHooks.add(fn),
  }
  provide(DraftKey, draft)
  return draft
}

export function useSettingsDraft(): Draft {
  const draft = inject(DraftKey)
  if (!draft) throw new Error('useSettingsDraft() needs provideSettingsDraft() in a parent component')
  return draft
}

/** A setting's value on screen: Cancel returns it to the last saved value, Save makes it the new one. */
export function useDraftValue<T>(initial: T): Ref<T> {
  const draft = useSettingsDraft()
  const copy = (value: T): T => structuredClone(toRaw(value))
  const value = ref(copy(initial)) as Ref<T>
  let saved = copy(initial)
  const reset = () => (value.value = copy(saved))
  const keep = () => (saved = copy(value.value))
  draft.onCancel(reset)
  draft.onSaved(keep)
  return value
}
