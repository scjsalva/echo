<script setup lang="ts">
import { inject, nextTick, onMounted, ref } from 'vue'
import { PhArrowCounterClockwise, PhSparkle } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import MarkdownEditor from '@/components/ui/MarkdownEditor.vue'
import SkillPicker from '@/components/ui/SkillPicker.vue'
import { useToast } from '@/composables/useToast'
import type { Rewrite } from '@/composables/useReview'

const props = withDefaults(defineProps<{ initial?: string; submitLabel?: string; rows?: number; repo?: string; askable?: boolean }>(), {
  initial: '',
  submitLabel: 'Add comment',
  rows: 3,
  repo: undefined,
})
const emit = defineEmits<{ submit: [body: string]; cancel: []; ask: [body: string, question: string] }>()

const asking = ref(false)
const question = ref('')
const questionBox = ref<HTMLTextAreaElement>()

async function startAsking() {
  asking.value = true
  await nextTick()
  questionBox.value?.focus()
}

function ask() {
  if (question.value.trim()) emit('ask', body.value.trim(), question.value.trim())
}

const body = ref(props.initial)
const box = ref<InstanceType<typeof MarkdownEditor>>()
onMounted(async () => {
  await nextTick()
  box.value?.focus()
})

function submit() {
  if (body.value.trim()) emit('submit', body.value.trim())
}

// Your rewrite skill, once chosen in Settings: rewrites what you've typed in place, with Undo.
const rewrite = inject<Rewrite | null>('rewrite', null)
const toast = useToast()
const rewriting = ref(false)
const before = ref<string | null>(null)
async function rewriteBody() {
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
  <div class="grid gap-2">
    <MarkdownEditor
      ref="box"
      v-model="body"
      :rows="rows"
      aria-label="Comment"
      placeholder="Leave a comment (Markdown)"
      @keydown.meta.enter="submit"
      @keydown.esc.stop="emit('cancel')"
    />
    <div class="flex flex-wrap gap-2">
      <BaseButton variant="primary" size="sm" :disabled="!body.trim()" @click="submit">{{ submitLabel }}</BaseButton>
      <BaseButton v-if="askable" size="sm" class="ai-border" tooltip="Ask Claude about this line; its answer can become the comment" @click="startAsking">
        <PhSparkle :size="13" weight="fill" class="ai-icon" /> Ask AI
      </BaseButton>
      <BaseButton
        v-if="rewrite?.skill.value"
        size="sm"
        class="ai-border"
        :disabled="rewriting || !body.trim()"
        :tooltip="`Rewrites what you've typed with your ${rewrite.skill.value} skill`"
        @click="rewriteBody"
      >
        <PhSparkle :size="13" weight="fill" :class="['ai-icon', rewriting && 'animate-pulse']" /> {{ rewriting ? 'Rewriting…' : 'Rewrite' }}
      </BaseButton>
      <BaseButton v-if="before !== null && !rewriting" size="sm" tooltip="Puts back what you had" @click="undo"><PhArrowCounterClockwise :size="13" /> Undo</BaseButton>
      <BaseButton size="sm" @click="emit('cancel')">Cancel</BaseButton>
    </div>
    <div v-if="asking" class="grid gap-1">
      <!-- A text box, so a question can run to a few lines; ⌘/Ctrl+Enter sends it. -->
      <form class="flex items-end gap-2" @submit.prevent="ask">
        <textarea
          ref="questionBox"
          v-model="question"
          rows="3"
          aria-label="Question for Claude about this line"
          placeholder="e.g. Is this safe if the list is empty?"
          class="min-w-0 flex-1 resize-y rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
          @keydown.esc.stop="asking = false"
          @keydown.meta.enter.prevent="ask"
          @keydown.ctrl.enter.prevent="ask"
        />
        <BaseButton size="sm" :disabled="!question.trim()" @click="ask">Ask</BaseButton>
      </form>
      <SkillPicker action="review_question" :repo="repo" class="justify-self-end" />
    </div>
  </div>
</template>
