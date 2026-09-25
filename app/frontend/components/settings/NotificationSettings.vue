<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhBellRinging } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import SettingRow from './SettingRow.vue'
import ToggleSwitch from '@/components/ui/ToggleSwitch.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { NotificationSettings } from '@/types/dashboard'

const props = defineProps<{ settings: NotificationSettings }>()

const toast = useToast()
const desktop = ref(props.settings.desktop)
const scope = ref(props.settings.scope)
const enabled = ref(new Set(props.settings.enabledTypes))
const sound = ref(props.settings.sound)

const scopes = [
  { value: 'waiting', label: 'Waiting on you' },
  { value: 'custom', label: 'Custom' },
] as const

const groups = computed(() => {
  const byGroup = new Map<string, NotificationSettings['types']>()
  for (const type of props.settings.types) byGroup.set(type.group, [...(byGroup.get(type.group) ?? []), type])
  return [...byGroup.entries()]
})

function toggle(id: string, on: boolean) {
  const next = new Set(enabled.value)
  if (on) next.add(id)
  else next.delete(id)
  enabled.value = next
  save({ notify_types: props.settings.types.map((t) => t.id).filter((t) => next.has(t)) })
}

async function save(change: Record<string, unknown>) {
  try {
    await request('PATCH', '/api/settings', change)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't save that")
  }
}

async function sendTest() {
  await request('POST', '/api/test_notification').catch(() => null)
  toast.show(`Sent. If nothing appeared, check that Echo is allowed in ${props.settings.settingsHint}.`)
}
</script>

<template>
  <SettingRow>
    <template #title>
      Notify me about
      <InfoHint text="Waiting on you covers blocked agents, review requests, mentions, changes requested on your PRs, and Jira assignments. Custom lets you pick from everything Echo can send." />
    </template>
    <template #description>Sent as OS notifications when those are on, otherwise as alerts on any open Echo page.</template>
    <SegmentedControl v-model="scope" :options="scopes" label="Notify me about" @update:model-value="save({ notify_scope: $event })" />
  </SettingRow>

  <div v-if="scope === 'custom'" class="grid gap-4 pb-3 sm:grid-cols-3" aria-label="Notifications to send">
    <fieldset v-for="[group, types] in groups" :key="group" class="grid content-start gap-1.5">
      <legend class="mb-1.5 text-[11px] font-medium tracking-[0.07em] text-faint uppercase">{{ group }}</legend>
      <label v-for="type in types" :key="type.id" class="flex cursor-pointer items-start gap-2 text-[13px]">
        <input
          type="checkbox"
          :checked="enabled.has(type.id)"
          class="mt-0.5 accent-(--color-accent)"
          @change="toggle(type.id, ($event.target as HTMLInputElement).checked)"
        />
        <span>{{ type.label }}</span>
      </label>
    </fieldset>
  </div>

  <SettingRow>
    <template #title>
      OS notifications
      <InfoHint
        :text="`The first time, your system may ask whether Echo can send notifications. If none appear, check that Echo is allowed in ${settings.settingsHint}.`"
      />
    </template>
    <template #description>
      <template v-if="!settings.available">This computer can't show them, so Echo uses in-app alerts instead.</template>
      <template v-else-if="desktop">Works even when no Echo page is open, and clears after 30 seconds. In-app alerts are off while these are on, so you're not told twice.</template>
      <template v-else>Off, so new items show as alerts on any open Echo page instead.</template>
    </template>
    <ToggleSwitch v-model="desktop" :disabled="!settings.available" label="OS notifications" @update:model-value="save({ notify_desktop: $event })" />
  </SettingRow>

  <SettingRow>
    <template #title>Sound</template>
    <template #description>Plays with each notification, whether it's an OS notification or an in-app alert.</template>
    <select
      v-model="sound"
      aria-label="Notification sound"
      class="rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
      @change="save({ notify_sound: sound })"
    >
      <option value="none">No sound</option>
      <option v-for="name in settings.sounds" :key="name" :value="name">{{ name }}</option>
    </select>
    <BaseButton :disabled="!desktop || !settings.available" tooltip="Sends a test OS notification with this sound" @click="sendTest">
      <PhBellRinging :size="14" /> Send test
    </BaseButton>
  </SettingRow>
</template>
