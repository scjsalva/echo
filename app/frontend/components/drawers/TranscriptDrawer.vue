<script setup lang="ts">
import { onMounted, ref } from 'vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import { request } from '@/lib/api'
import type { TranscriptMessage } from '@/types/dashboard'

const props = defineProps<{ id: string; title: string }>()

const messages = ref<TranscriptMessage[] | null>(null)
const failed = ref(false)

const ROLE: Record<TranscriptMessage['role'], { label: string; classes: string }> = {
  you: { label: 'You', classes: 'text-accent' },
  claude: { label: 'Claude', classes: '' },
  tool: { label: 'Tool', classes: 'rounded-md bg-subtle px-2.5 py-1.5 font-mono text-xs text-muted' },
}

onMounted(async () => {
  try {
    messages.value = (await request<{ messages: TranscriptMessage[] }>('GET', `/api/agents/${props.id}/transcript`)).messages
  } catch {
    failed.value = true
  }
})
</script>

<template>
  <SideDrawer :label="`Transcript: ${title}`">
    <template #eyebrow><span class="text-xs text-faint">Transcript · read-only · latest 200 messages</span></template>
    <template #title>{{ title }}</template>

    <p v-if="failed" class="text-bad">Couldn't load the transcript.</p>
    <p v-else-if="!messages" class="text-faint">Loading…</p>
    <p v-else-if="!messages.length" class="text-faint">This session has no messages yet.</p>
    <ol v-else class="grid gap-3">
      <li v-for="(message, i) in messages" :key="i" class="grid max-w-prose gap-0.5">
        <span class="font-mono text-[11px] tracking-wide text-faint uppercase">{{ ROLE[message.role].label }}</span>
        <p :class="['whitespace-pre-line break-words', ROLE[message.role].classes]">{{ message.text }}</p>
      </li>
    </ol>
  </SideDrawer>
</template>
