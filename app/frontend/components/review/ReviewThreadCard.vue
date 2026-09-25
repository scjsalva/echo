<script setup lang="ts">
import { PhArrowSquareOut, PhChatsCircle } from '@phosphor-icons/vue'
import CommentThread from '@/components/ui/CommentThread.vue'
import type { ReviewThread } from '@/types/dashboard'

defineProps<{ thread: ReviewThread }>()
</script>

<template>
  <article class="grid gap-2 rounded-lg border border-warn/40 bg-surface px-3 py-2.5 font-sans shadow-sm" aria-label="Unresolved thread">
    <header class="flex flex-wrap items-center gap-2 text-[12.5px]">
      <span class="inline-flex items-center gap-1 font-medium text-warn"><PhChatsCircle :size="14" weight="fill" /> Unresolved on GitHub</span>
      <span v-if="thread.outdated && thread.originalLine" class="text-faint">was line {{ thread.originalLine }}</span>
      <a v-if="thread.comments[0]?.url" :href="thread.comments[0].url" target="_blank" rel="noopener" class="ml-auto inline-flex items-center gap-1 text-faint hover:text-ink">
        Reply on GitHub <PhArrowSquareOut :size="12" />
      </a>
    </header>
    <CommentThread
      v-for="(comment, i) in thread.comments"
      :key="comment.id"
      :author="comment.author"
      :at="comment.at"
      :url="comment.url"
      :body="comment.body"
      markdown
      :nested="i > 0"
    />
  </article>
</template>
