<script setup lang="ts">
import UserAvatar from '@/components/ui/UserAvatar.vue'
import { useDrawer } from '@/composables/useDrawer'
import type { JiraTicket } from '@/types/dashboard'

defineProps<{ ticket: JiraTicket }>()
const { open } = useDrawer()
</script>

<!-- A card like Jira's board: the title, then type and key, with priority and who has it. -->
<template>
  <button
    type="button"
    class="grid w-full gap-2 rounded-md border border-line bg-surface px-3 py-2.5 text-left shadow-sm hover:border-accent/40 hover:bg-subtle"
    @click="open({ type: 'ticket', key: ticket.key, ticket })"
  >
    <span class="text-[13px] wrap-anywhere">{{ ticket.title }}</span>
    <span v-if="ticket.sprint" class="justify-self-start rounded bg-subtle px-1.5 py-0.5 text-[11px] text-muted">{{ ticket.sprint }}</span>
    <span class="flex flex-wrap items-center gap-x-2 gap-y-1">
      <span class="text-[11px] whitespace-nowrap text-faint">{{ ticket.type }}</span>
      <span class="font-mono text-xs font-medium whitespace-nowrap text-jira">{{ ticket.key }}</span>
      <span class="ml-auto flex items-center gap-2">
        <span v-if="ticket.priority" class="font-mono text-[11px] text-muted">{{ ticket.priority }}</span>
        <UserAvatar v-if="ticket.assignee" :name="ticket.assignee" />
        <span v-else class="size-5 rounded-full border border-dashed border-line" title="Unassigned" aria-label="Unassigned" />
      </span>
    </span>
  </button>
</template>
