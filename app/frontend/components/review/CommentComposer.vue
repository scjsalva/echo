<script setup lang="ts">
import { nextTick, onMounted, ref } from 'vue'
import BaseButton from '@/components/ui/BaseButton.vue'

const props = withDefaults(defineProps<{ initial?: string; submitLabel?: string; rows?: number }>(), { initial: '', submitLabel: 'Add comment', rows: 3 })
const emit = defineEmits<{ submit: [body: string]; cancel: [] }>()

const body = ref(props.initial)
const box = ref<HTMLTextAreaElement>()
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
    <textarea
      ref="box"
      v-model="body"
      :rows="rows"
      aria-label="Comment"
      placeholder="Leave a comment"
      class="w-full rounded-md border border-line bg-surface px-2.5 py-2 font-sans text-[13px]"
      @keydown.meta.enter="submit"
      @keydown.esc.stop="emit('cancel')"
    />
    <div class="flex gap-2">
      <BaseButton variant="primary" size="sm" :disabled="!body.trim()" @click="submit">{{ submitLabel }}</BaseButton>
      <BaseButton size="sm" @click="emit('cancel')">Cancel</BaseButton>
    </div>
  </div>
</template>
