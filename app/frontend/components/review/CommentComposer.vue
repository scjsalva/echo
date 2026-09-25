<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import { PhSparkle } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import MarkdownEditor from '@/components/ui/MarkdownEditor.vue'
import SkillPicker from '@/components/ui/SkillPicker.vue'

const props = withDefaults(defineProps<{ initial?: string; submitLabel?: string; rows?: number; repo?: string; askable?: boolean }>(), {
  initial: '',
  submitLabel: 'Add comment',
  rows: 3,
  repo: undefined,
})
const emit = defineEmits<{ submit: [body: string]; cancel: []; ask: [body: string, question: string] }>()

const asking = ref(false)
const question = ref('')
const questionBox = ref<HTMLInputElement>()

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
    <div class="flex gap-2">
      <BaseButton variant="primary" size="sm" :disabled="!body.trim()" @click="submit">{{ submitLabel }}</BaseButton>
      <BaseButton v-if="askable" size="sm" class="ai-border" tooltip="Ask Claude about this line; its answer can become the comment" @click="startAsking">
        <PhSparkle :size="13" weight="fill" class="ai-icon" /> Ask AI
      </BaseButton>
      <BaseButton size="sm" @click="emit('cancel')">Cancel</BaseButton>
    </div>
    <div v-if="asking" class="grid gap-1">
      <form class="flex gap-2" @submit.prevent="ask">
        <input
          ref="questionBox"
          v-model="question"
          aria-label="Question for Claude about this line"
          placeholder="e.g. Is this safe if the list is empty?"
          class="min-w-0 flex-1 rounded-md border border-line bg-surface px-2.5 py-1 text-[13px]"
          @keydown.esc.stop="asking = false"
        />
        <BaseButton size="sm" :disabled="!question.trim()" @click="ask">Ask</BaseButton>
      </form>
      <SkillPicker action="review_question" :repo="repo" class="justify-self-end" />
    </div>
  </div>
</template>
