<script setup lang="ts">
import { watch } from 'vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import SettingRow from './SettingRow.vue'
import { useSettingsDraft } from '@/composables/useSettingsDraft'
import { useTheme } from '@/composables/useTheme'

const { preference } = useTheme()
const draft = useSettingsDraft()
const themes = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
] as const

// It shows as you pick it; Cancel puts back the one you had.
let saved = preference.value
watch(preference, (value) => value !== saved && draft.stage('theme', async () => undefined))
draft.onCancel(() => (preference.value = saved))
draft.onSaved(() => (saved = preference.value))
</script>

<template>
  <SettingRow>
    <template #title>Theme</template>
    <template #description>System follows your computer.</template>
    <SegmentedControl v-model="preference" :options="themes" label="Theme" />
  </SettingRow>
</template>
