<script setup lang="ts">
import { ref } from 'vue'
import { PhArrowCounterClockwise, PhCopy } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import PagedList from '@/components/ui/PagedList.vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import TableCard from '@/components/ui/TableCard.vue'
import { useDrawer } from '@/composables/useDrawer'
import { useNow } from '@/composables/useNow'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import { formatTokens, timeAgo } from '@/lib/format'
import type { EndedSession } from '@/types/dashboard'

const { open } = useDrawer()
const toast = useToast()
const now = useNow(60_000)
const query = ref('')

// Pages continue from the last session shown.
async function load(loaded: EndedSession[]) {
  const params = new URLSearchParams()
  const last = loaded.at(-1)
  if (last) params.set('before', last.cursor)
  if (query.value.trim()) params.set('q', query.value.trim())
  const page = await request<{ items: EndedSession[]; nextCursor: string | null }>('GET', `/api/ended_sessions?${params}`)
  return { items: page.items, more: Boolean(page.nextCursor) }
}

async function resume(session: EndedSession) {
  try {
    await request('POST', `/api/ended_sessions/${session.id}/resume`)
    toast.show('Opened in Terminal')
  } catch {
    toast.show("Couldn't open Terminal. Copy the command instead.")
  }
}

async function copy(session: EndedSession) {
  try {
    await navigator.clipboard.writeText(session.resumeCommand)
    toast.show('Resume command copied')
  } catch {
    toast.show(session.resumeCommand)
  }
}
</script>

<template>
  <section>
    <SectionHeader title="Ended sessions" meta="Newest first" />
    <input
      v-model="query"
      type="search"
      placeholder="Search by title, folder or branch"
      aria-label="Search ended sessions"
      class="mb-3 w-full max-w-sm rounded-md border border-line bg-surface px-3 py-1.5 text-[13px] placeholder:text-faint"
    />
    <PagedList :load="load" :reset-key="query">
      <template #default="{ items: sessions, done }">
        <TableCard>
          <thead>
            <tr><th>Session</th><th>Folder</th><th class="text-right">Turns</th><th class="text-right">Tokens</th><th class="text-right">Ended</th><th /></tr>
          </thead>
          <tbody>
            <tr v-if="done && !sessions.length">
              <td colspan="6" class="py-6 text-center text-faint">{{ query ? 'No ended sessions match.' : 'No ended sessions yet.' }}</td>
            </tr>
            <tr
              v-for="session in sessions"
              :key="session.id"
              class="cursor-pointer hover:bg-subtle"
              @click="open({ type: 'transcript', id: session.id, title: session.title })"
            >
              <td class="max-w-[420px]">
                <span class="line-clamp-2 font-medium break-words">{{ session.title }}</span>
                <span v-if="session.lastReply" class="line-clamp-2 text-[12.5px] break-words text-muted">{{ session.lastReply }}</span>
              </td>
              <td class="text-xs break-all text-muted">{{ session.cwd }}<template v-if="session.branch"> · {{ session.branch }}</template></td>
              <td class="text-right font-mono tabular-nums">{{ session.turns }}</td>
              <td class="text-right font-mono tabular-nums">{{ formatTokens(session.tokensTotal) }}</td>
              <td class="text-right text-xs whitespace-nowrap text-faint">{{ timeAgo(session.ended, now) }} ago</td>
              <td class="text-right whitespace-nowrap" @click.stop>
                <span class="inline-flex gap-1.5">
                  <BaseButton size="sm" tooltip="Opens Terminal and runs claude --resume in the session's folder" @click="resume(session)">
                    <PhArrowCounterClockwise :size="13" /> Resume
                  </BaseButton>
                  <BaseButton size="sm" :tooltip="`Copy: ${session.resumeCommand}`" aria-label="Copy resume command" @click="copy(session)">
                    <PhCopy :size="13" />
                  </BaseButton>
                </span>
              </td>
            </tr>
          </tbody>
        </TableCard>
      </template>
    </PagedList>
  </section>
</template>
