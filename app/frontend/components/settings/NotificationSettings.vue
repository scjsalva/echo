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
const reminder = ref(props.settings.reminderMinutes)

const hours = ref({ ...props.settings.workingHours })
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
// Monday first, as a working week reads.
const dayOrder = [1, 2, 3, 4, 5, 6, 0]
const overnight = computed(() => hours.value.end <= hours.value.start && hours.value.end !== hours.value.start)
function saveHours() {
  save({ working_hours: { enabled: hours.value.enabled, days: hours.value.days, start: hours.value.start, end: hours.value.end } })
}
function toggleDay(day: number) {
  const days = new Set(hours.value.days)
  if (!days.delete(day)) days.add(day)
  hours.value = { ...hours.value, days: [...days].sort() }
  saveHours()
}
const every = (minutes: number) => (minutes === 0 ? 'Off' : minutes < 60 ? `Every ${minutes} minutes` : minutes === 60 ? 'Every hour' : `Every ${minutes / 60} hours`)

const scopes = [
  {
    value: 'waiting',
    label: 'Simple',
    hint: "Just what's waiting on you: an agent waiting for permission or an answer, a review requested from you, you or your team mentioned on a PR, changes requested on your PR, you mentioned on a Jira ticket, or a Jira ticket assigned to you. Plus the review reminder, if it's on.",
  },
  { value: 'custom', label: 'Custom', hint: undefined },
] as const

const groups = computed(() => {
  const byGroup = new Map<string, NotificationSettings['types']>()
  for (const type of props.settings.types) byGroup.set(type.group, [...(byGroup.get(type.group) ?? []), type])
  return byGroup
})
// Three columns: Agents with System below it, then GitHub, then Jira.
const columns = computed(() =>
  [['Agents', 'System'], ['GitHub'], ['Jira']]
    .map((names) => names.filter((name) => groups.value.has(name)).map((name) => [name, groups.value.get(name)!] as const))
    .filter((column) => column.length),
)
// Unticking the reminder in the list turns it off, so its own setting has nothing to set.
const reminderOff = computed(() => scope.value === 'custom' && !enabled.value.has('system.review_reminder'))

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
      <InfoHint text="Simple sends only what's waiting on you. Custom lets you pick from everything Echo can send." />
    </template>
    <template #description>Sent as OS notifications when those are on, otherwise as alerts on any open Echo page.</template>
    <SegmentedControl v-model="scope" :options="scopes" label="Notify me about" @update:model-value="save({ notify_scope: $event })" />
  </SettingRow>

  <div v-if="scope === 'custom'" class="grid gap-4 pb-3 sm:grid-cols-3" aria-label="Notifications to send">
    <div v-for="(column, c) in columns" :key="c" class="grid content-start gap-4">
      <fieldset v-for="[group, types] in column" :key="group" class="grid content-start gap-1.5">
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
  </div>

  <SettingRow>
    <template #title>Working hours</template>
    <template #description>
      <template v-if="hours.enabled">
        Notifications only come in these hours, in {{ hours.timeZone }} (change it in General). Anything from outside them arrives when they start.
        <template v-if="overnight"> Ends after midnight, so it counts as the day it starts.</template>
      </template>
      <template v-else>Off, so notifications can come at any time.</template>
    </template>
    <ToggleSwitch v-model="hours.enabled" label="Working hours" @update:model-value="saveHours" />
  </SettingRow>
  <div v-if="hours.enabled" class="flex flex-wrap items-center gap-x-5 gap-y-3 pb-3" aria-label="Working hours">
    <div class="flex flex-wrap gap-1" role="group" aria-label="Working days">
      <button
        v-for="day in dayOrder"
        :key="day"
        type="button"
        :aria-pressed="hours.days.includes(day)"
        :class="[
          'rounded-md border px-2 py-1 text-[12.5px] font-medium',
          hours.days.includes(day) ? 'border-accent bg-accent-soft text-accent' : 'border-line text-muted hover:text-ink',
        ]"
        @click="toggleDay(day)"
      >
        {{ DAYS[day] }}
      </button>
    </div>
    <label class="flex items-center gap-2 text-[13px] text-muted">
      From
      <input v-model="hours.start" type="time" aria-label="Start" class="rounded-md border border-line bg-surface px-2 py-1 text-[13px] text-ink" @change="saveHours" />
      to
      <input v-model="hours.end" type="time" aria-label="End" class="rounded-md border border-line bg-surface px-2 py-1 text-[13px] text-ink" @change="saveHours" />
    </label>
  </div>

  <SettingRow :class="reminderOff && 'opacity-50'">
    <template #title>Review reminder</template>
    <template #description>
      <template v-if="reminderOff">Off, because it's unticked in the list above. Tick it to choose how often.</template>
      <template v-else>Says how many PRs in your review queue are waiting for review, leaving out approved ones. Only sent while there are some.</template>
    </template>
    <select
      v-model.number="reminder"
      aria-label="Review reminder"
      :disabled="reminderOff"
      class="rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px] disabled:cursor-not-allowed"
      @change="save({ review_reminder_minutes: reminder })"
    >
      <option v-for="minutes in settings.reminderOptions" :key="minutes" :value="minutes">{{ every(minutes) }}</option>
    </select>
  </SettingRow>

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
