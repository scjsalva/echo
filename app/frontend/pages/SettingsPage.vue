<script setup lang="ts">
import { ref } from 'vue'
import AppShell from '@/components/layout/AppShell.vue'
import ConnectionRow from '@/components/settings/ConnectionRow.vue'
import SegmentedControl from '@/components/ui/SegmentedControl.vue'
import SettingRow from '@/components/settings/SettingRow.vue'
import SettingsCard from '@/components/settings/SettingsCard.vue'
import ClaudeSettings from '@/components/settings/ClaudeSettings.vue'
import GithubSettings from '@/components/settings/GithubSettings.vue'
import NotificationSettings from '@/components/settings/NotificationSettings.vue'
import TimeZoneSetting from '@/components/settings/TimeZoneSetting.vue'
import { useTheme } from '@/composables/useTheme'
import type { ClaudeSettings as ClaudePreferences, Connection, GithubPreferences, NotificationSettings as NotificationPreferences, ShellProps, TimeZoneSettings } from '@/types/dashboard'

const props = defineProps<{
  shell: ShellProps
  connections: Connection[]
  timeZone: TimeZoneSettings
  notifications: NotificationPreferences
  github: GithubPreferences
  claude: ClaudePreferences
}>()

const connections = ref(props.connections)

const { preference } = useTheme()
const themes = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
] as const
</script>

<template>
  <AppShell :shell="shell" title="Settings" :show-first-run="false">
    <div class="grid max-w-3xl gap-4">
      <SettingsCard id="connections" title="Connections" description="Claude Code sessions work out of the box. These connect the rest, through tools you already use.">
        <ConnectionRow v-for="connection in connections" :key="connection.key" :connection="connection" @change="connections = $event" />
      </SettingsCard>

      <SettingsCard id="github" title="GitHub">
        <GithubSettings :preferences="github" />
      </SettingsCard>

      <SettingsCard id="skills" title="Claude" description="The skills behind Echo's AI actions, and your own instructions that go with them.">
        <ClaudeSettings :settings="claude" />
      </SettingsCard>

      <SettingsCard title="Notifications">
        <NotificationSettings :settings="notifications" />
      </SettingsCard>

      <SettingsCard title="Time">
        <TimeZoneSetting :time-zone="timeZone" />
      </SettingsCard>

      <SettingsCard title="Appearance">
        <SettingRow>
          <template #title>Theme</template>
          <template #description>System follows your computer.</template>
          <SegmentedControl v-model="preference" :options="themes" label="Theme" />
        </SettingRow>
      </SettingsCard>
    </div>
  </AppShell>
</template>
