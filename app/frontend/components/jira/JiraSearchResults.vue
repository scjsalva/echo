<script setup lang="ts">
import JiraTicketRow from './JiraTicketRow.vue'
import PagedList from '@/components/ui/PagedList.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import { request } from '@/lib/api'
import type { JiraTicket } from '@/types/dashboard'

const props = defineProps<{ query: string; type: string; now: number }>()

function load(loaded: JiraTicket[]) {
  const params = new URLSearchParams({ q: props.query, seen: loaded.map((t) => t.key).join(',') })
  if (props.type !== 'all') params.set('type', props.type)
  return request<{ items: JiraTicket[]; more: boolean }>('GET', `/api/jira/search?${params}`)
}
</script>

<template>
  <section>
    <SectionHeader title="Results from all of Jira" :meta="`“${query}”`" />
    <PagedList :load="load" :reset-key="[query, type]" loading-text="Searching Jira…">
      <template #default="{ items, done }">
        <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
          <p v-if="done && !items.length" class="px-4 py-6 text-center text-[13px] text-faint">Jira has no tickets matching “{{ query }}” either.</p>
          <JiraTicketRow v-for="ticket in items" :key="ticket.key" :ticket="ticket" :now="now" />
        </div>
      </template>
    </PagedList>
  </section>
</template>
