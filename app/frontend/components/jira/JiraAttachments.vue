<script setup lang="ts">
import { ref } from 'vue'
import { PhArrowSquareOut, PhPaperclip } from '@phosphor-icons/vue'
import type { JiraTicketDetail } from '@/types/dashboard'

// Echo can't download Jira attachments, so images load straight from Jira in
// your browser, with your Jira login. One that won't load (not logged in, or
// the browser blocks Jira's cookie here) is just listed like any other file.
defineProps<{ files: JiraTicketDetail['attachments']; fallback: string }>()

const broken = ref(new Set<string>())
const fileSize = (bytes: number) => (bytes >= 1_048_576 ? `${(bytes / 1_048_576).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`)
</script>

<template>
  <ul class="divide-y divide-line-soft rounded-lg border border-line-soft">
    <li v-for="file in files" :key="`${file.name}-${file.created}`">
      <a :href="file.url ?? fallback" target="_blank" rel="noopener" class="grid gap-2 px-3 py-2 text-[13px] hover:bg-subtle">
        <img
          v-if="file.thumbnail && !broken.has(file.thumbnail)"
          :src="file.thumbnail"
          :alt="file.name"
          loading="lazy"
          class="max-h-64 max-w-full justify-self-start rounded-md border border-line-soft"
          @error="broken = new Set([...broken, file.thumbnail])"
        />
        <span class="flex items-center gap-2">
          <PhPaperclip :size="14" class="shrink-0 text-faint" />
          <span class="min-w-0 flex-1 wrap-anywhere">{{ file.name }}</span>
          <span class="shrink-0 text-xs text-faint">{{ fileSize(file.size) }}</span>
          <PhArrowSquareOut :size="12" class="shrink-0 text-faint" />
        </span>
      </a>
    </li>
  </ul>
</template>
