<script setup lang="ts">
import { computed } from 'vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import SettingRow from './SettingRow.vue'
import { useDraftValue, useSettingsDraft } from '@/composables/useSettingsDraft'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { TimeZoneSettings } from '@/types/dashboard'

const props = defineProps<{ timeZone: TimeZoneSettings }>()

const AUTOMATIC = 'auto'
const toast = useToast()
const draft = useSettingsDraft()
const preference = useDraftValue(props.timeZone.preference)

const automaticLabel = computed(() => `Automatic (${props.timeZone.detected})`)

function stage() {
  draft.stage('time_zone', async () => {
    const { timeZone } = await request<{ timeZone: TimeZoneSettings }>('PATCH', '/api/settings', { time_zone: preference.value })
    toast.show(`"Today" now follows ${timeZone.current}`)
  })
}
</script>

<template>
  <SettingRow>
    <template #title>
      Time zone
      <InfoHint text="Decides when your day starts for figures like tokens used today. Automatic follows your computer, including when you travel." />
    </template>
    <template #description>{{ preference === AUTOMATIC ? `Following your computer: ${timeZone.detected}` : 'Set by you' }}</template>
    <select
      v-model="preference"
      aria-label="Time zone"
      class="max-w-72 rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
      @change="stage"
    >
      <option :value="AUTOMATIC">{{ automaticLabel }}</option>
      <option v-for="zone in timeZone.options" :key="zone.value" :value="zone.value">{{ zone.label }}</option>
    </select>
  </SettingRow>
</template>
