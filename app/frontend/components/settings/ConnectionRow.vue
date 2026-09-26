<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { PhPlugs, PhPlugsConnected, PhSignOut, PhTerminalWindow } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import SettingRow from './SettingRow.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { Connection } from '@/types/dashboard'

const props = defineProps<{ connection: Connection }>()
const emit = defineEmits<{ change: [connections: Connection[]] }>()

const POLL_MS = 3000
const GIVE_UP_MS = 5 * 60_000

const toast = useToast()
const waiting = ref(false)
const busy = ref(false)
let poll: ReturnType<typeof setInterval> | undefined

async function fetchConnections(): Promise<Connection[]> {
  const { connections } = await request<{ connections: Connection[] }>('GET', '/api/connections?fresh=1')
  emit('change', connections)
  return connections
}

function stopWaiting() {
  clearInterval(poll)
  waiting.value = false
}

async function install() {
  busy.value = true
  try {
    await request('POST', `/api/connections/${props.connection.key}/setup`)
    await fetchConnections()
    toast.show(
      props.connection.key === 'claude_integration'
        ? 'Installed. Try /echo in Claude Code; the status line shows up on its next refresh.'
        : 'Hooks installed. Sessions you start from now on will use them.',
    )
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't install it")
  } finally {
    busy.value = false
  }
}

// Terminal handles the login; Echo just watches until the connection reports in.
async function setUp() {
  try {
    await request('POST', `/api/connections/${props.connection.key}/setup`)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't open Terminal")
    return
  }
  waiting.value = true
  const startedAt = Date.now()
  poll = setInterval(async () => {
    const current = (await fetchConnections().catch(() => [])).find((c) => c.key === props.connection.key)
    if (current?.connected) {
      stopWaiting()
      toast.show(`${props.connection.name} connected`)
    } else if (Date.now() - startedAt > GIVE_UP_MS) {
      stopWaiting()
      toast.show(`Still not connected to ${props.connection.name}. Try Set up again.`)
    }
  }, POLL_MS)
}

async function disconnect() {
  busy.value = true
  try {
    await request('DELETE', `/api/connections/${props.connection.key}`)
    await fetchConnections()
    toast.show(props.connection.instant ? `${props.connection.name} removed` : `Logged out of ${props.connection.name}`)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't log out")
  } finally {
    busy.value = false
  }
}

onBeforeUnmount(stopWaiting)
</script>

<template>
  <SettingRow>
    <template #title>
      {{ connection.name }}
      <BasePill v-if="connection.connected" tone="ok">Connected</BasePill>
      <BasePill v-else-if="waiting" tone="accent">Waiting for you to log in…</BasePill>
      <BasePill v-else-if="connection.optional">Optional</BasePill>
      <BasePill v-else tone="warn">Not connected</BasePill>
    </template>
    <template v-if="connection.detail || waiting" #description>
      <span class="break-words">{{ waiting ? 'Finish logging in in the Terminal window and your browser. This updates by itself.' : connection.detail }}</span>
    </template>
    <template v-if="connection.instant">
      <BaseButton v-if="connection.connected" :disabled="busy" tooltip="Takes Echo's hooks out of your Claude Code settings" @click="disconnect">
        <PhPlugs :size="14" /> Remove
      </BaseButton>
      <BaseButton
        v-else
        :disabled="busy"
        tooltip="Adds Echo's hooks to ~/.claude/settings.json next to your other hooks, after backing the file up"
        @click="install"
      >
        <PhPlugsConnected :size="14" /> Install
      </BaseButton>
    </template>
    <template v-else-if="connection.setup">
      <BaseButton v-if="connection.connected && connection.logout === false" disabled tooltip="Echo shares your gh login with your terminal, so log out there with gh auth logout">
        <PhSignOut :size="14" /> Log out
      </BaseButton>
      <BaseButton v-else-if="connection.connected" :disabled="busy" tooltip="Logs out so you can set it up again" @click="disconnect">
        <PhSignOut :size="14" /> Log out
      </BaseButton>
      <BaseButton v-else-if="waiting" @click="stopWaiting">Cancel</BaseButton>
      <BaseButton v-else tooltip="Opens Terminal to log in" @click="setUp"><PhTerminalWindow :size="14" /> Set up</BaseButton>
    </template>
    <BaseButton v-else-if="!connection.connected" soon="Comes when this connection is built">
      <PhTerminalWindow :size="14" /> Set up
    </BaseButton>
  </SettingRow>
</template>
