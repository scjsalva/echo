<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { PhSparkle } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'

/** Before Claude reviews: anything you want it to focus on or know. */
const props = defineProps<{ initial?: string | null; again: boolean }>()
const emit = defineEmits<{ start: [guidance: string]; cancel: [] }>()

const guidance = ref(props.initial ?? '')
const root = ref<HTMLElement>()
const box = ref<HTMLTextAreaElement>()
const onKey = (e: KeyboardEvent) => e.key === 'Escape' && emit('cancel')
// Clicks on the button that opened it are left to that button, so it can toggle.
const onPointer = (e: PointerEvent) => !root.value?.parentElement?.contains(e.target as Node) && emit('cancel')
onMounted(() => {
  document.addEventListener('keydown', onKey)
  document.addEventListener('pointerdown', onPointer)
  box.value?.focus()
})
onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKey)
  document.removeEventListener('pointerdown', onPointer)
})
</script>

<template>
  <div
    ref="root"
    role="dialog"
    aria-label="Start AI review"
    class="ai-border absolute top-full right-0 z-30 mt-2 grid w-[min(460px,calc(100vw-2rem))] gap-3 rounded-lg border p-4 text-left shadow-xl"
  >
    <header class="grid gap-1">
      <h2 class="text-[14px] font-semibold">{{ again ? 'Review again' : 'Start AI review' }}</h2>
      <p class="text-[12.5px] text-muted">Claude reads the PR's code and stages comments for you to commit. Nothing is posted.</p>
    </header>
    <textarea
      ref="box"
      v-model="guidance"
      rows="5"
      aria-label="Direction for Claude"
      placeholder="Anything for Claude? (optional) e.g. focus on app/models/order.rb, check it meets the ticket's acceptance criteria, ignore the test changes"
      class="w-full rounded-md border border-line bg-surface px-2.5 py-2 text-[13px]"
      @keydown.meta.enter="emit('start', guidance.trim())"
    />
    <footer class="flex items-center justify-between gap-2 border-t border-line-soft pt-3">
      <span class="text-[11.5px] text-faint">⌘↩ to start</span>
      <span class="flex gap-2">
        <BaseButton @click="emit('cancel')">Cancel</BaseButton>
        <BaseButton variant="primary" @click="emit('start', guidance.trim())">
          <PhSparkle :size="14" weight="fill" /> Start review
        </BaseButton>
      </span>
    </footer>
  </div>
</template>
