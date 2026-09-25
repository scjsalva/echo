<script setup lang="ts">
import { ref } from 'vue'
import MarkdownBlock from './MarkdownBlock.vue'

// Attributes and listeners (aria-label, placeholder, keydown) go on the textarea.
defineOptions({ inheritAttrs: false })

const props = withDefaults(defineProps<{ rows?: number }>(), { rows: 4 })
const body = defineModel<string>({ required: true })

const tab = ref<'write' | 'preview'>('write')
const box = ref<HTMLTextAreaElement>()

defineExpose({ focus: () => box.value?.focus() })

const TAB = 'rounded-md px-2 py-0.5 text-[12px] font-medium'
</script>

<template>
  <div class="grid gap-1.5">
    <div class="flex gap-1" role="tablist">
      <button type="button" role="tab" :aria-selected="tab === 'write'" :class="[TAB, tab === 'write' ? 'bg-subtle text-ink' : 'text-muted hover:text-ink']" @click="tab = 'write'">
        Write
      </button>
      <button type="button" role="tab" :aria-selected="tab === 'preview'" :class="[TAB, tab === 'preview' ? 'bg-subtle text-ink' : 'text-muted hover:text-ink']" @click="tab = 'preview'">
        Preview
      </button>
    </div>
    <textarea
      v-show="tab === 'write'"
      ref="box"
      v-model="body"
      v-bind="$attrs"
      :rows="props.rows"
      class="w-full rounded-md border border-line bg-surface px-2.5 py-2 font-sans text-[13px]"
    />
    <div
      v-if="tab === 'preview'"
      class="overflow-y-auto rounded-md border border-line bg-surface px-3 py-2"
      :style="{ minHeight: `${props.rows * 1.25 + 1}rem` }"
      aria-label="Preview"
    >
      <MarkdownBlock v-if="body.trim()" :source="body" />
      <p v-else class="text-[13px] text-faint">Nothing to preview.</p>
    </div>
  </div>
</template>
