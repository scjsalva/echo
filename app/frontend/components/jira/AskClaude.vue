<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { PhArrowCounterClockwise, PhTerminalWindow } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import { timeAgo } from '@/lib/format'
import type { TicketSessionOptions } from '@/types/dashboard'

const props = defineProps<{ ticketKey: string }>()

const toast = useToast()
const options = ref<TicketSessionOptions | null>(null)
const starting = ref(false)
const error = ref<string | null>(null)

const path = `/api/jira/tickets/${props.ticketKey}/session`

onMounted(async () => {
  await load()
})

async function load() {
  options.value = await request<TicketSessionOptions>('GET', path).catch(() => null)
}

async function launch(action: () => Promise<unknown>, done: string) {
  starting.value = true
  error.value = null
  try {
    await action()
    toast.show(done)
    await load()
  } catch (e) {
    error.value = e instanceof Error ? e.message : "Couldn't open Claude"
  } finally {
    starting.value = false
  }
}

const start = () => launch(() => request('POST', path), `Opened Claude on ${props.ticketKey} in Terminal`)
const resume = () =>
  launch(() => request('POST', `${path}/resume`), options.value?.lastSession?.live ? 'Brought its tab forward' : `Resumed the ${props.ticketKey} session in Terminal`)
</script>

<template>
  <template v-if="options">
    <a v-if="!options.repos.length" href="/settings#github" class="text-[12.5px] text-muted hover:text-accent">Set a local repo in Settings to ask Claude</a>
    <template v-else>
      <BaseButton class="ai-border" :disabled="starting" tooltip="Opens Claude Code in a new Terminal tab with this ticket as its brief, to talk it through before you pick it up. It can read all your local repos and works out with you which the change belongs in. It only reads until you ask it to build." @click="start">
        <PhTerminalWindow :size="14" class="ai-icon" /> {{ options.lastSession ? 'Ask again' : 'Ask Claude' }}
      </BaseButton>
      <BaseButton
        v-if="options.lastSession?.resumable"
        class="ai-border"
        :disabled="starting"
        :tooltip="options.lastSession.live ? 'Still running: brings its Terminal tab forward.' : `Picks up the session Echo opened ${timeAgo(options.lastSession.openedAt)} ago, in a new Terminal tab.`"
        @click="resume"
      >
        <PhArrowCounterClockwise :size="14" class="ai-icon" /> {{ options.lastSession.live ? 'Go to session' : 'Resume session' }}
      </BaseButton>
    </template>
    <p v-if="error" class="basis-full text-[12.5px] text-bad">{{ error }}</p>
  </template>
</template>
