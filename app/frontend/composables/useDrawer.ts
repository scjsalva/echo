import { computed, inject, provide, ref, type ComputedRef, type InjectionKey, type Ref } from 'vue'
import type { JiraTicket } from '@/types/dashboard'

export type DrawerTarget =
  | { type: 'agent'; id: string }
  | { type: 'pullRequest'; key: string; notificationId?: string }
  | { type: 'ticket'; key: string; notificationId?: string; ticket?: JiraTicket }
  | { type: 'waiting'; key: string }
  | { type: 'transcript'; id: string; title: string }

interface Drawer {
  target: Ref<DrawerTarget | null>
  canGoBack: ComputedRef<boolean>
  /** Opens a panel; if one is already open it's remembered so Back returns to it. */
  open: (target: DrawerTarget) => void
  back: () => void
  close: () => void
}

const DrawerKey: InjectionKey<Drawer> = Symbol('drawer')

export function provideDrawer(): Drawer {
  const target = ref<DrawerTarget | null>(null)
  const history = ref<DrawerTarget[]>([])

  const drawer: Drawer = {
    target,
    canGoBack: computed(() => history.value.length > 0),
    open(next) {
      if (target.value) history.value.push(target.value)
      target.value = next
    },
    back() {
      target.value = history.value.pop() ?? null
    },
    close() {
      history.value = []
      target.value = null
    },
  }
  provide(DrawerKey, drawer)
  return drawer
}

export function useDrawer(): Drawer {
  const drawer = inject(DrawerKey)
  if (!drawer) throw new Error('useDrawer() needs provideDrawer() in a parent component')
  return drawer
}
