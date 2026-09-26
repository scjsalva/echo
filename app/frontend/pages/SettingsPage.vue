<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { PhBell, PhGithubLogo, PhPlugs, PhSlidersHorizontal, PhSparkle } from '@phosphor-icons/vue'
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

// One section at a time, picked from the list on the left. The address follows
// it (/settings#claude), so links from elsewhere land on the right one.
type Section = 'connections' | 'github' | 'claude' | 'notifications' | 'general'
const sections = computed(() => [
  { id: 'connections' as const, label: 'Connections', icon: PhPlugs, attention: connections.value.some((c) => !c.connected) },
  { id: 'github' as const, label: 'GitHub', icon: PhGithubLogo, attention: false },
  { id: 'claude' as const, label: 'Claude', icon: PhSparkle, attention: false },
  { id: 'notifications' as const, label: 'Notifications', icon: PhBell, attention: false },
  { id: 'general' as const, label: 'General', icon: PhSlidersHorizontal, attention: false },
])
// Older links still work, e.g. the skill picker's /settings#skills.
const ALIASES: Record<string, Section> = { skills: 'claude', time: 'general', appearance: 'general' }
const section = ref<Section>('connections')

function fromHash() {
  const id = location.hash.slice(1)
  const match = ALIASES[id] ?? sections.value.find((s) => s.id === id)?.id
  if (match) section.value = match
}
function select(id: Section) {
  section.value = id
  history.replaceState(null, '', `#${id}`)
  window.scrollTo({ top: 0 })
}
onMounted(() => {
  fromHash()
  window.addEventListener('hashchange', fromHash)
})
onBeforeUnmount(() => window.removeEventListener('hashchange', fromHash))

const { preference } = useTheme()
const themes = [
  { value: 'system', label: 'System' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
] as const
</script>

<template>
  <AppShell
    :shell="shell"
    :title="sections.find((s) => s.id === section)?.label"
    :trail="[{ label: 'Settings', href: '/settings' }]"
    :show-first-run="false"
  >
    <div class="grid items-start gap-6 md:grid-cols-[200px_minmax(0,48rem)] md:gap-8">
      <nav aria-label="Settings sections" class="flex flex-wrap gap-1 md:sticky md:top-4 md:flex-col">
        <button
          v-for="item in sections"
          :key="item.id"
          type="button"
          :aria-current="section === item.id ? 'page' : undefined"
          :class="[
            'flex items-center gap-2 rounded-md px-3 py-1.5 text-left text-[13.5px] font-medium',
            section === item.id ? 'bg-surface text-ink shadow-sm ring-1 ring-line' : 'text-muted hover:bg-subtle hover:text-ink',
          ]"
          @click="select(item.id)"
        >
          <component :is="item.icon" :size="15" :weight="section === item.id ? 'fill' : 'regular'" />
          {{ item.label }}
          <span v-if="item.attention" class="ml-auto size-1.5 rounded-full bg-warn" aria-label="Needs attention" />
        </button>
      </nav>

      <div class="grid gap-4">
        <!-- v-show, not v-if: each section keeps what you changed while you look at another. -->
        <SettingsCard v-show="section === 'connections'" title="Connections" description="Claude Code sessions work out of the box. These connect the rest, through tools you already use.">
          <ConnectionRow v-for="connection in connections" :key="connection.key" :connection="connection" @change="connections = $event" />
        </SettingsCard>

        <SettingsCard v-show="section === 'github'" title="GitHub">
          <GithubSettings :preferences="github" />
        </SettingsCard>

        <SettingsCard v-show="section === 'claude'" title="Skills" description="The skill behind each of Echo's AI actions, for all repos or one.">
          <ClaudeSettings :settings="claude" part="skills" />
        </SettingsCard>
        <SettingsCard
          v-show="section === 'claude'"
          title="What Claude sees"
          description="Every AI review, question and summary Echo runs includes your own Claude instructions, sent to Claude the same way Claude Code sends them when you use it."
        >
          <ClaudeSettings :settings="claude" part="context" />
        </SettingsCard>

        <SettingsCard v-show="section === 'notifications'" title="Notifications">
          <NotificationSettings :settings="notifications" />
        </SettingsCard>

        <SettingsCard v-show="section === 'general'" title="Time">
          <TimeZoneSetting :time-zone="timeZone" />
        </SettingsCard>
        <SettingsCard v-show="section === 'general'" title="Appearance">
          <SettingRow>
            <template #title>Theme</template>
            <template #description>System follows your computer.</template>
            <SegmentedControl v-model="preference" :options="themes" label="Theme" />
          </SettingRow>
        </SettingsCard>
      </div>
    </div>
  </AppShell>
</template>
