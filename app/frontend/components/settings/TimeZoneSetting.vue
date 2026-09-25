<script setup lang="ts">
import { computed, ref } from 'vue'
import InfoHint from '@/components/ui/InfoHint.vue'
import SettingRow from './SettingRow.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { TimeZoneSettings } from '@/types/dashboard'

const props = defineProps<{ timeZone: TimeZoneSettings }>()

const AUTOMATIC = 'auto'
const toast = useToast()
const preference = ref(props.timeZone.preference)
const saving = ref(false)

const automaticLabel = computed(() => `Automatic (${props.timeZone.detected})`)

async function save() {
  saving.value = true
  try {
    const { timeZone } = await request<{ timeZone: TimeZoneSettings }>('PATCH', '/api/settings', { time_zone: preference.value })
    toast.show(`"Today" now follows ${timeZone.current}`)
  } catch (error) {
    preference.value = props.timeZone.preference
    toast.show(error instanceof Error ? error.message : "Couldn't save the time zone")
  } finally {
    saving.value = false
  }
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
      :disabled="saving"
      aria-label="Time zone"
      class="max-w-72 rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
      @change="save"
    >
      <option :value="AUTOMATIC">{{ automaticLabel }}</option>
      <option v-for="zone in timeZone.options" :key="zone.value" :value="zone.value">{{ zone.label }}</option>
    </select>
  </SettingRow>
</template>
