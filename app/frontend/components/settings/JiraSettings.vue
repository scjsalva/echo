<script setup lang="ts">
import { ref } from 'vue'
import { PhArrowDown, PhArrowUp, PhMagnifyingGlass, PhTrash } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import ToggleSwitch from '@/components/ui/ToggleSwitch.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { JiraBoard, JiraBoards } from '@/types/dashboard'

const props = defineProps<{ preferences: JiraBoards }>()

const toast = useToast()
const prefs = ref(props.preferences)
const busy = ref(false)

// Board changes go to Jira's settings straight away, rather than waiting for Save.
async function change(method: 'POST' | 'PATCH' | 'DELETE', path: string, body: unknown, done: string) {
  busy.value = true
  try {
    prefs.value = await request<JiraBoards>(method, path, body)
    toast.show(done)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't change the boards")
  } finally {
    busy.value = false
  }
}

const query = ref('')
const results = ref<{ id: number; name: string; location: string | null; type: string }[] | null>(null)
const searching = ref(false)
async function search() {
  if (!query.value.trim()) return
  searching.value = true
  try {
    results.value = (await request<{ boards: NonNullable<typeof results.value> }>('GET', `/api/jira/boards/search?${new URLSearchParams({ q: query.value.trim() })}`)).boards
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't search boards")
  } finally {
    searching.value = false
  }
}
async function add(id: number, name: string) {
  await change('POST', '/api/jira/boards', { id }, `Added ${name}. Its tickets arrive in a moment.`)
  results.value = results.value?.filter((b) => b.id !== id) ?? null
}

function arrange(board: JiraBoard, statuses: JiraBoard['statuses'], done: string) {
  change('PATCH', `/api/jira/boards/${board.id}`, { statuses: statuses.map(({ name, hidden }) => ({ name, hidden })) }, done)
}
function move(board: JiraBoard, index: number, by: number) {
  const statuses = [...board.statuses]
  ;[statuses[index], statuses[index + by]] = [statuses[index + by], statuses[index]]
  arrange(board, statuses, 'Statuses reordered')
}
function setShown(board: JiraBoard, index: number, shown: boolean) {
  arrange(board, board.statuses.map((s, i) => (i === index ? { ...s, hidden: !shown } : s)), shown ? 'Status shown' : 'Status hidden')
}
</script>

<template>
  <!-- Its own bottom room, like a setting row gives the other cards. -->
  <div class="grid gap-4 pb-3">
    <p class="text-[12.5px] text-muted">
      The board you follow is the Jira page's board, and what the Overview counts. Its Backlog starts hidden, as Jira keeps it off the board. Echo follows one board; to switch, remove it and find another. Changes here apply straight away.
    </p>

    <p v-if="!prefs.boards.length" class="rounded-md border border-dashed border-line px-3 py-4 text-center text-[13px] text-faint">No board yet. Find yours below.</p>
    <article v-for="board in prefs.boards" :key="board.id" class="grid gap-3 rounded-lg border border-line px-4 py-3">
      <header class="flex flex-wrap items-center gap-2">
        <span class="font-medium">{{ board.name }}</span>
        <span v-if="board.location" class="text-[12.5px] text-faint">{{ board.location }}</span>
        <span class="ml-auto flex gap-1.5">
          <BaseButton size="sm" :disabled="busy" :tooltip="`Stop following ${board.name}`" @click="change('DELETE', `/api/jira/boards/${board.id}`, undefined, `Removed ${board.name}`)">
            <PhTrash :size="13" /> Remove
          </BaseButton>
        </span>
      </header>
      <div>
        <h4 class="mb-1 text-[11px] font-medium tracking-[0.07em] text-faint uppercase">Statuses, in board order</h4>
        <p v-if="!board.statuses.length" class="text-[12.5px] text-faint">They appear once its tickets have synced.</p>
        <ol v-else class="divide-y divide-line-soft">
          <li v-for="(status, i) in board.statuses" :key="status.name" class="flex items-center gap-2 py-1.5 text-[13px]">
            <span :class="['min-w-0 flex-1 wrap-anywhere', status.hidden && 'text-faint line-through']">{{ status.name }}</span>
            <button type="button" class="rounded p-1 text-muted hover:bg-subtle disabled:opacity-30" :disabled="busy || i === 0" :aria-label="`Move ${status.name} up`" @click="move(board, i, -1)">
              <PhArrowUp :size="13" />
            </button>
            <button type="button" class="rounded p-1 text-muted hover:bg-subtle disabled:opacity-30" :disabled="busy || i === board.statuses.length - 1" :aria-label="`Move ${status.name} down`" @click="move(board, i, 1)">
              <PhArrowDown :size="13" />
            </button>
            <ToggleSwitch :model-value="!status.hidden" :label="`Show ${status.name}`" :disabled="busy" @update:model-value="(shown) => setShown(board, i, shown)" />
          </li>
        </ol>
      </div>
    </article>

    <form v-if="!prefs.boards.length" class="flex flex-wrap gap-2" @submit.prevent="search">
      <label class="relative min-w-0 flex-1">
        <PhMagnifyingGlass :size="14" class="pointer-events-none absolute top-1/2 left-2.5 -translate-y-1/2 text-faint" />
        <input v-model="query" type="search" placeholder="Find a board by name" aria-label="Find a board" class="w-full rounded-md border border-line bg-surface py-1.5 pr-3 pl-8 text-[13px] placeholder:text-faint" />
      </label>
      <BaseButton :disabled="searching || !query.trim()" @click="search">{{ searching ? 'Searching…' : 'Search' }}</BaseButton>
    </form>
    <ul v-if="results && !prefs.boards.length" class="divide-y divide-line-soft rounded-lg border border-line-soft">
      <li v-if="!results.length" class="px-3 py-2.5 text-[13px] text-faint">No boards match.</li>
      <li v-for="board in results" :key="board.id" class="flex flex-wrap items-center gap-2 px-3 py-2 text-[13px]">
        <span class="font-medium">{{ board.name }}</span>
        <span class="text-[12.5px] text-faint">{{ board.location }} · {{ board.type }}</span>
        <BaseButton size="sm" class="ml-auto" :disabled="busy" @click="add(board.id, board.name)">Add</BaseButton>
      </li>
    </ul>

  </div>
</template>
