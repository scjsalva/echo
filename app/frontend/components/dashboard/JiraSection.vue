<script setup lang="ts">
import { computed } from 'vue'
import CollapsibleSection from '@/components/ui/CollapsibleSection.vue'
import MiniRow from './MiniRow.vue'
import SideEmpty from './SideEmpty.vue'
import SideGroupLabel from './SideGroupLabel.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { usePersistentFlag } from '@/composables/usePersistentFlag'
import { JIRA_GROUP_TITLES, jiraKind } from '@/lib/labels'
import type { JiraCategory, JiraNotification, JiraTicket } from '@/types/dashboard'

const props = defineProps<{ tickets: JiraTicket[]; notifications: JiraNotification[] }>()

const { open } = useDrawer()
const { markRead } = useDashboard()
const expanded = usePersistentFlag('overview.jira', false)

const BOARD_ORDER: JiraCategory[] = ['in_progress', 'code_review', 'post_development', 'todo']
const PER_GROUP = 3

const board = computed(() =>
  BOARD_ORDER.map((category) => props.tickets.filter((t) => t.assignedToMe && t.category === category)).filter((group) => group.length),
)
const openCount = computed(() => board.value.reduce((sum, group) => sum + group.length, 0))
const unread = computed(() => props.notifications.filter((n) => n.unread))
</script>

<template>
  <CollapsibleSection v-model:open="expanded" title="Jira" :summary="`${openCount} open · ${unread.length} unread`">
    <SideEmpty v-if="!board.length" class="mt-3">No open tickets assigned to you.</SideEmpty>
    <template v-for="group in board" :key="group[0].category">
      <SideGroupLabel>{{ JIRA_GROUP_TITLES[group[0].category] }} · {{ group.length }}</SideGroupLabel>
      <MiniRow v-for="ticket in group.slice(0, PER_GROUP)" :key="ticket.key" @select="open({ type: 'ticket', key: ticket.key })">
        <template #lead><span class="font-mono text-xs font-medium text-jira">{{ ticket.key }}</span></template>
        {{ ticket.title }}
      </MiniRow>
      <a v-if="group.length > PER_GROUP" href="/jira" class="px-0 py-1 text-[12.5px] font-medium text-accent hover:opacity-80">
        +{{ group.length - PER_GROUP }} more in {{ JIRA_GROUP_TITLES[group[0].category].toLowerCase() }} →
      </a>
    </template>

    <template v-if="unread.length">
      <SideGroupLabel>Unread</SideGroupLabel>
      <MiniRow v-for="n in unread" :key="n.id" @select="markRead(n.id); open({ type: 'ticket', key: n.key, notificationId: n.id })">
        <template #lead><span class="font-mono text-xs font-medium text-jira">{{ n.key }}</span></template>
        {{ n.actor ? `${n.actor} · ${jiraKind[n.kind].label.toLowerCase()}` : jiraKind[n.kind].label }}
        <template v-if="n.body" #sub>{{ n.kind === 'transition' ? n.body : `“${n.body}”` }}</template>
      </MiniRow>
    </template>

    <div class="mt-2.5 flex flex-wrap gap-x-4 text-[12.5px] font-medium text-accent">
      <a href="/jira" class="hover:opacity-80">All Jira →</a>
      <a href="/inbox" class="hover:opacity-80">Notifications →</a>
    </div>
  </CollapsibleSection>
</template>
