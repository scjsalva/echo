<script setup lang="ts">
import JiraTicketRow from './JiraTicketRow.vue'
import PagedList from '@/components/ui/PagedList.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import { request } from '@/lib/api'
import type { JiraTicket } from '@/types/dashboard'

const props = defineProps<{ scope: string; type: string; now: number }>()

// Jira's search can't page by date, so each page skips the tickets already shown.
function load(loaded: JiraTicket[]) {
  const params = new URLSearchParams({ scope: props.scope, seen: loaded.map((t) => t.key).join(',') })
  if (props.type !== 'all') params.set('type', props.type)
  return request<{ items: JiraTicket[]; more: boolean }>('GET', `/api/jira/done_tickets?${params}`)
}
</script>

<template>
  <section>
    <SectionHeader title="Done" meta="Newest first" />
    <PagedList :load="load" :reset-key="[scope, type]" loading-text="Loading from Jira…">
      <template #default="{ items, done }">
        <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
          <p v-if="done && !items.length" class="px-4 py-6 text-center text-[13px] text-faint">No done tickets here.</p>
          <JiraTicketRow v-for="ticket in items" :key="ticket.key" :ticket="ticket" :now="now" />
        </div>
      </template>
    </PagedList>
  </section>
</template>
