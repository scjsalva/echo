<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhCaretRight } from '@phosphor-icons/vue'
import BasePill from './BasePill.vue'
import MarkdownBlock from './MarkdownBlock.vue'
import UserAvatar from './UserAvatar.vue'
import { timeAgo } from '@/lib/format'
import type { Tone } from '@/lib/labels'

const props = withDefaults(
  defineProps<{
    author: string | null
    bot?: boolean
    at: string
    url?: string | null
    body: string
    /** GitHub bodies are markdown; Jira bodies are plain text. */
    markdown?: boolean
    pill?: { label: string; tone: Tone }
    /** Indents a reply under its thread's root. */
    nested?: boolean
  }>(),
  { bot: false, url: null, markdown: false, nested: false },
)

// A bot comment (CI, ci-bot[bot]) is noise until asked for; a human one always opens.
const expanded = ref(!props.bot)

// Roughly 8 lines at drawer width, without measuring layout.
const isLong = computed(() => props.body.split('\n').length > 8 || props.body.length > 600)
const clamped = ref(true)
</script>

<template>
  <div class="overflow-hidden rounded-lg border border-line-soft" :class="nested && 'ml-6'">
    <button
      v-if="bot && !expanded"
      type="button"
      class="flex w-full items-center gap-2 bg-subtle px-3 py-1.5 text-left text-[12.5px] text-faint hover:text-ink"
      @click="expanded = true"
    >
      <UserAvatar v-if="author" :name="author" />
      <span class="min-w-0 break-words">{{ author ?? 'Someone' }}</span>
      <span>· {{ timeAgo(at) }} ago</span>
      <PhCaretRight :size="11" weight="bold" class="ml-auto shrink-0" />
    </button>
    <template v-else>
      <div class="flex flex-wrap items-center gap-2 border-b border-line-soft bg-subtle px-3 py-2 text-[12.5px]">
        <UserAvatar v-if="author" :name="author" />
        <strong class="min-w-0 font-medium break-words">{{ author ?? 'Someone' }}</strong>
        <BasePill v-if="bot">Bot</BasePill>
        <BasePill v-if="pill" :tone="pill.tone">{{ pill.label }}</BasePill>
        <a v-if="url" :href="url" target="_blank" rel="noopener" class="text-faint hover:text-ink">{{ timeAgo(at) }} ago</a>
        <span v-else class="text-faint">{{ timeAgo(at) }} ago</span>
        <button v-if="bot" type="button" class="ml-auto shrink-0 text-faint hover:text-ink" @click="expanded = false">
          <PhCaretRight :size="11" weight="bold" class="rotate-90" />
        </button>
      </div>
      <div class="bg-surface px-3 py-2.5">
        <div :class="['text-[13px] leading-relaxed', isLong && clamped && 'line-clamp-[8]']">
          <MarkdownBlock v-if="markdown" :source="body" />
          <p v-else class="whitespace-pre-line break-words">{{ body }}</p>
        </div>
        <button v-if="isLong" type="button" class="mt-1.5 text-[12px] font-medium text-accent hover:opacity-80" @click="clamped = !clamped">
          {{ clamped ? 'Show more' : 'Show less' }}
        </button>
      </div>
    </template>
  </div>
</template>
