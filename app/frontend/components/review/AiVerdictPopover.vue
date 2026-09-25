<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { PhCheckCircle, PhSparkle } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import MarkdownBlock from '@/components/ui/MarkdownBlock.vue'
import type { ReviewDraft } from '@/types/dashboard'

defineProps<{ report: NonNullable<ReviewDraft['aiReport']> }>()
const emit = defineEmits<{ close: []; useAsSummary: [] }>()

const root = ref<HTMLElement>()
const onKey = (e: KeyboardEvent) => e.key === 'Escape' && emit('close')
// Clicks on the button that opened it are left to that button, so it can toggle.
const onPointer = (e: PointerEvent) => !root.value?.parentElement?.contains(e.target as Node) && emit('close')
onMounted(() => {
  document.addEventListener('keydown', onKey)
  document.addEventListener('pointerdown', onPointer)
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
    aria-label="Claude's verdict"
    class="ai-border absolute top-full right-0 z-30 mt-2 grid max-h-[70vh] w-[min(560px,calc(100vw-2rem))] gap-2 overflow-y-auto rounded-lg border border-line bg-surface p-4 text-left text-[13px] shadow-xl"
  >
    <p :class="['flex items-start gap-1.5 font-semibold', report.added ? 'text-accent' : 'text-ok']">
      <component :is="report.added ? PhSparkle : PhCheckCircle" :size="16" weight="fill" :class="['mt-px shrink-0', report.added && 'ai-icon']" />
      {{ report.added ? `Claude added ${report.added} comment${report.added === 1 ? '' : 's'}` : 'Claude found no problems' }}
    </p>
    <MarkdownBlock :source="report.summary" />
    <BaseButton size="sm" class="justify-self-start" tooltip="Opens Send review with this as the summary, for you to edit" @click="emit('useAsSummary')">
      Use as review summary
    </BaseButton>
    <details v-if="report.leftOut.length" class="border-t border-line-soft pt-2 text-[12.5px] text-muted">
      <summary class="cursor-pointer select-none">{{ report.leftOut.length }} finding{{ report.leftOut.length === 1 ? '' : 's' }} left out</summary>
      <ul class="mt-1.5 grid gap-2">
        <li v-for="(f, i) in report.leftOut" :key="i" class="grid gap-0.5">
          <span class="font-mono text-[11.5px] break-all">{{ f.path }}:{{ f.line }} · {{ f.reason }}</span>
          <span class="text-ink">{{ f.body }}</span>
        </li>
      </ul>
    </details>
  </div>
</template>
