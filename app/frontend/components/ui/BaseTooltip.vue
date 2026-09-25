<script setup lang="ts">
import { onBeforeUnmount, ref, useId } from 'vue'

defineOptions({ inheritAttrs: false })
const props = withDefaults(defineProps<{ text: string; placement?: 'top' | 'bottom' }>(), { placement: 'top' })

const HALF_WIDTH = 136
const trigger = ref<HTMLElement>()
const visible = ref(false)
const position = ref({ x: 0, y: 0 })
const id = useId()
let timer: ReturnType<typeof setTimeout> | undefined

function show() {
  clearTimeout(timer)
  timer = setTimeout(() => {
    const rect = trigger.value?.getBoundingClientRect()
    if (!rect) return
    // Keep the bubble on screen when the trigger sits near an edge.
    const x = Math.min(Math.max(rect.left + rect.width / 2, HALF_WIDTH), window.innerWidth - HALF_WIDTH)
    position.value = { x, y: props.placement === 'top' ? rect.top - 8 : rect.bottom + 8 }
    visible.value = true
    document.addEventListener('keydown', onKey)
  }, 250)
}

function hide() {
  clearTimeout(timer)
  visible.value = false
  document.removeEventListener('keydown', onKey)
}

const onKey = (e: KeyboardEvent) => e.key === 'Escape' && hide()
onBeforeUnmount(hide)
</script>

<template>
  <span
    ref="trigger"
    v-bind="$attrs"
    class="inline-flex"
    :aria-describedby="visible ? id : undefined"
    @mouseenter="show"
    @mouseleave="hide"
    @focusin="show"
    @focusout="hide"
  ><slot /></span>
  <Teleport to="body">
    <span
      v-if="visible"
      :id="id"
      role="tooltip"
      :class="[
        'pointer-events-none fixed z-50 w-max max-w-64 -translate-x-1/2 rounded-md bg-ink px-2.5 py-1.5 text-xs leading-snug font-normal tracking-normal text-canvas normal-case shadow-lg',
        placement === 'top' && '-translate-y-full',
      ]"
      :style="{ left: `${position.x}px`, top: `${position.y}px` }"
    >{{ text }}</span>
  </Teleport>
</template>
