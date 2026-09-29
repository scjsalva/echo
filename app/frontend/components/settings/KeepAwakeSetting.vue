<script setup lang="ts">
import { computed } from 'vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import SettingRow from './SettingRow.vue'
import { useDraftValue, useSettingsDraft } from '@/composables/useSettingsDraft'
import { request } from '@/lib/api'
import type { KeepAwakeSettings } from '@/types/dashboard'

const props = defineProps<{ keepAwake: KeepAwakeSettings; workingHoursOn: boolean }>()

const draft = useSettingsDraft()
const mode = useDraftValue(props.keepAwake.mode)

const options = computed(() => [
  { value: 'off', label: 'Off' },
  { value: 'agents', label: 'While agents are working' },
  { value: 'working_hours', label: props.workingHoursOn ? 'During working hours' : 'All the time (working hours are off)' },
])

// Plain about the cost, so a draining battery is never a mystery.
const description = computed(() => {
  switch (mode.value) {
    case 'agents':
      return 'Your computer stays awake while a Claude Code session or one of Echo\'s AI reviews is working, and for 2 minutes after, so a long task isn\'t cut short by sleep. It sleeps as usual once they\'re idle or waiting on you.'
    case 'working_hours':
      return props.workingHoursOn
        ? 'Your computer never goes to sleep by itself during your working hours (set in Notifications), even with nothing running. On battery this drains it noticeably faster.'
        : "Your computer never goes to sleep by itself while Echo runs, even with nothing running, because working hours are off. On battery this drains it noticeably faster; set working hours in Notifications to limit it."
    default:
      return 'Your computer sleeps on its usual schedule, which pauses agents and syncs until it wakes.'
  }
})

function stage() {
  draft.stage('keep_awake', () => request('PATCH', '/api/settings', { keep_awake: mode.value }))
}
</script>

<template>
  <SettingRow>
    <template #title>
      Keep the computer awake
      <InfoHint
        text="Stops your computer going to sleep when idle, the way music playing or a big download does: it keeps working, but the screen still turns off and locks on its usual timer, and closing a laptop's lid still puts it to sleep. The more it stays awake, the more battery it uses."
      />
    </template>
    <template #description>
      <template v-if="!keepAwake.available">This computer has no way for Echo to ask it to stay awake.</template>
      <template v-else>
        {{ description }}
        <span v-if="keepAwake.current" class="text-accent"> Keeping awake now: {{ keepAwake.current }}.</span>
      </template>
    </template>
    <select
      v-model="mode"
      aria-label="Keep the computer awake"
      :disabled="!keepAwake.available"
      class="rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px] disabled:cursor-not-allowed"
      @change="stage"
    >
      <option v-for="option in options" :key="option.value" :value="option.value">{{ option.label }}</option>
    </select>
  </SettingRow>
</template>
