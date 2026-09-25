<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { PhArrowLeft, PhX } from '@phosphor-icons/vue'
import { useDrawer } from '@/composables/useDrawer'

// Drawers opened through useDrawer close through it; a standalone one passes onClose.
const props = withDefaults(defineProps<{ label: string; side?: 'left' | 'right'; onClose?: () => void }>(), { side: 'right' })

const drawer = props.onClose ? null : useDrawer()
const canGoBack = computed(() => drawer?.canGoBack.value ?? false)
const back = () => drawer?.back()
const close = () => (props.onClose ? props.onClose() : drawer!.close())
const panel = ref<HTMLElement>()
const onKey = (e: KeyboardEvent) => e.key === 'Escape' && close()

onMounted(async () => {
  document.addEventListener('keydown', onKey)
  await nextTick()
  panel.value?.focus()
})
onBeforeUnmount(() => document.removeEventListener('keydown', onKey))
</script>

<template>
  <div class="fixed inset-0 z-20 bg-black/35" @click="close" />
  <aside
    ref="panel"
    role="dialog"
    aria-modal="true"
    :aria-label="label"
    tabindex="-1"
    :class="[
      'fixed inset-y-0 z-30 w-full max-w-[560px] overflow-y-auto border-line bg-surface shadow-2xl outline-none',
      side === 'left' ? 'left-0 border-r' : 'right-0 border-l',
    ]"
  >
    <header class="sticky top-0 z-10 grid gap-2.5 border-b border-line-soft bg-surface px-5 pt-4 pb-3">
      <div class="flex flex-wrap items-center gap-2">
        <button
          v-if="canGoBack"
          type="button"
          class="-ml-1 inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[12.5px] text-muted hover:bg-subtle hover:text-ink"
          @click="back"
        >
          <PhArrowLeft :size="14" /> Back
        </button>
        <slot name="eyebrow" />
        <button type="button" class="ml-auto rounded-md p-1 text-muted hover:bg-subtle" aria-label="Close" @click="close">
          <PhX :size="16" />
        </button>
      </div>
      <h3 class="text-base font-semibold tracking-tight text-balance"><slot name="title" /></h3>
      <div v-if="$slots.actions" class="flex flex-wrap gap-2"><slot name="actions" /></div>
    </header>
    <div class="grid gap-5 px-5 pt-4 pb-8"><slot /></div>
  </aside>
</template>
