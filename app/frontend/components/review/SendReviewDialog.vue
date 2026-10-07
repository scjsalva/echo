<script setup lang="ts">
import { inject, onBeforeUnmount, onMounted, ref } from 'vue'
import { PhArrowCounterClockwise, PhSparkle } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import MarkdownEditor from '@/components/ui/MarkdownEditor.vue'
import { useToast } from '@/composables/useToast'
import type { Rewrite } from '@/composables/useReview'

defineProps<{ committed: number; staged: number; ownPr: boolean }>()
const emit = defineEmits<{ send: [event: 'comment' | 'approve' | 'request_changes', body: string]; cancel: [] }>()

type Event = 'comment' | 'approve' | 'request_changes'
const EVENTS: { value: Event; label: string; hint: string }[] = [
  { value: 'comment', label: 'Comment', hint: 'Feedback without approving' },
  { value: 'approve', label: 'Approve', hint: 'Good to merge' },
  { value: 'request_changes', label: 'Request changes', hint: 'Needs changes before it can merge' },
]

// Held by the page, so closing the dropdown doesn't lose what you wrote.
const event = defineModel<Event>('event', { default: 'comment' })
const body = defineModel<string>('body', { default: '' })
const sending = ref(false)

const root = ref<HTMLElement>()
const box = ref<InstanceType<typeof MarkdownEditor>>()
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

function send() {
  sending.value = true
  emit('send', event.value, body.value)
}

defineExpose({ done: () => (sending.value = false) })

// Your rewrite skill, once chosen in Settings: it rewrites the summary in place, with Undo.
const rewrite = inject<Rewrite | null>('rewrite', null)
const toast = useToast()
const rewriting = ref(false)
const before = ref<string | null>(null)
async function rewriteSummary() {
  rewriting.value = true
  try {
    const text = await rewrite!.text(body.value)
    before.value = body.value
    body.value = text
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't rewrite it")
  } finally {
    rewriting.value = false
  }
}
function undo() {
  body.value = before.value ?? body.value
  before.value = null
}
</script>

<template>
  <div
    ref="root"
    role="dialog"
    aria-label="Send review"
    class="absolute top-full right-0 z-30 mt-2 grid w-[min(480px,calc(100vw-2rem))] gap-3 rounded-lg border border-line bg-surface p-4 text-left shadow-xl"
  >
    <header class="grid gap-1">
      <h2 class="text-[14px] font-semibold">Finish your review</h2>
      <p class="text-[12.5px] text-muted">
        {{ committed }} committed comment{{ committed === 1 ? '' : 's' }} will be posted.
        <template v-if="staged"> {{ staged }} staged comment{{ staged === 1 ? '' : 's' }} won't be, unless you commit them first.</template>
      </p>
    </header>

    <MarkdownEditor ref="box" v-model="body" :rows="10" aria-label="Review summary" placeholder="Leave a summary (optional, Markdown)" />
    <div v-if="rewrite?.skill.value" class="flex flex-wrap items-center gap-2">
      <BaseButton
        size="sm"
        class="ai-border"
        :disabled="rewriting || !body.trim()"
        :tooltip="`Rewrites the summary with your ${rewrite.skill.value} skill`"
        @click="rewriteSummary"
      >
        <PhSparkle :size="13" weight="fill" :class="['ai-icon', rewriting && 'animate-pulse']" /> {{ rewriting ? 'Rewriting…' : 'Rewrite' }}
      </BaseButton>
      <BaseButton v-if="before !== null && !rewriting" size="sm" tooltip="Puts back what you had" @click="undo"><PhArrowCounterClockwise :size="13" /> Undo</BaseButton>
    </div>

    <fieldset class="grid gap-2.5">
      <legend class="sr-only">Decision</legend>
      <label v-for="option in EVENTS" :key="option.value" :class="['flex items-start gap-2.5', ownPr && option.value !== 'comment' ? 'opacity-50' : 'cursor-pointer']">
        <input v-model="event" type="radio" name="event" :value="option.value" :disabled="ownPr && option.value !== 'comment'" class="mt-1 accent-(--color-accent)" />
        <span class="grid">
          <span class="text-[13px] font-medium">{{ option.label }}</span>
          <span class="text-[12px] text-muted">{{ ownPr && option.value !== 'comment' ? "GitHub doesn't allow this on your own PR" : option.hint }}</span>
        </span>
      </label>
    </fieldset>

    <footer class="flex justify-end gap-2 border-t border-line-soft pt-3">
      <BaseButton @click="emit('cancel')">Cancel</BaseButton>
      <BaseButton variant="primary" :disabled="sending || (!committed && !body.trim() && event === 'comment')" @click="send">
        {{ sending ? 'Sending…' : 'Submit review' }}
      </BaseButton>
    </footer>
  </div>
</template>
