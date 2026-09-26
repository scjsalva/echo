<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref, watch } from 'vue'
import { PhBell, PhGithubLogo, PhPlugs, PhSlidersHorizontal, PhSparkle } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import ConnectionRow from '@/components/settings/ConnectionRow.vue'
import SettingsCard from '@/components/settings/SettingsCard.vue'
import SettingsSection from '@/components/settings/SettingsSection.vue'
import SyncHealthCard from '@/components/settings/SyncHealthCard.vue'
import ThemeSetting from '@/components/settings/ThemeSetting.vue'
import ClaudeSettings from '@/components/settings/ClaudeSettings.vue'
import GithubSettings from '@/components/settings/GithubSettings.vue'
import NotificationSettings from '@/components/settings/NotificationSettings.vue'
import TimeZoneSetting from '@/components/settings/TimeZoneSetting.vue'
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

// The tab title follows the breadcrumb, e.g. "Claude · Settings · Echo".
watch(section, (id) => (document.title = `${sections.value.find((s) => s.id === id)?.label} · Settings · Echo`), { immediate: true })

function fromHash() {
  const id = location.hash.slice(1)
  const match = ALIASES[id] ?? sections.value.find((s) => s.id === id)?.id
  if (!match || match === section.value) return
  if (canLeave(section.value)) section.value = match
  else history.replaceState(null, '', `#${section.value}`)
}
function select(id: Section) {
  if (id === section.value || !canLeave(section.value)) return
  section.value = id
  history.replaceState(null, '', `#${id}`)
  window.scrollTo({ top: 0 })
}
onMounted(() => {
  fromHash()
  window.addEventListener('hashchange', fromHash)
})
onBeforeUnmount(() => window.removeEventListener('hashchange', fromHash))

// Each section has its own Save and Cancel. Moving to another section, or
// leaving Settings, with unsaved changes asks first.
const dirty = reactive<Partial<Record<Section, boolean>>>({})
const sectionRefs: Partial<Record<Section, InstanceType<typeof SettingsSection>>> = {}
const setSectionRef = (id: Section) => (el: unknown) => {
  if (el) sectionRefs[id] = el as InstanceType<typeof SettingsSection>
}
function canLeave(id: Section) {
  if (!dirty[id]) return true
  const label = sections.value.find((s) => s.id === id)?.label
  if (!window.confirm(`You have unsaved changes in ${label}. Discard them?`)) return false
  sectionRefs[id]?.cancel()
  return true
}
const warnBeforeLeaving = (event: BeforeUnloadEvent) => {
  if (!Object.values(dirty).some(Boolean)) return
  event.preventDefault()
  event.returnValue = ''
}
onMounted(() => window.addEventListener('beforeunload', warnBeforeLeaving))
onBeforeUnmount(() => window.removeEventListener('beforeunload', warnBeforeLeaving))
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
          <span v-if="dirty[item.id]" class="ml-auto size-1.5 rounded-full bg-accent" aria-label="Unsaved changes" />
          <span v-else-if="item.attention" class="ml-auto size-1.5 rounded-full bg-warn" aria-label="Needs attention" />
        </button>
      </nav>

      <!-- v-show, not v-if: each section keeps what you changed while you look at another. -->
      <div>
        <SettingsSection v-show="section === 'connections'" :ref="setSectionRef('connections')" label="Connections" @dirty="dirty.connections = $event">
          <SettingsCard title="Connections" description="Claude Code sessions work out of the box. These connect the rest, through tools you already use.">
            <ConnectionRow v-for="connection in connections" :key="connection.key" :connection="connection" @change="connections = $event" />
          </SettingsCard>
          <SettingsCard title="Health" description="How Echo's background syncs are doing. Each retries on its own; Sync now runs one straight away.">
            <SyncHealthCard />
          </SettingsCard>
        </SettingsSection>

        <SettingsSection v-show="section === 'github'" :ref="setSectionRef('github')" label="GitHub" @dirty="dirty.github = $event">
          <SettingsCard title="GitHub">
            <GithubSettings :preferences="github" />
          </SettingsCard>
        </SettingsSection>

        <SettingsSection v-show="section === 'claude'" :ref="setSectionRef('claude')" label="Claude" @dirty="dirty.claude = $event">
          <SettingsCard title="Skills" description="The skill behind each of Echo's AI actions, for all repos or one.">
            <ClaudeSettings :settings="claude" part="skills" />
          </SettingsCard>
          <SettingsCard
            title="What Claude sees"
            description="Every AI review, question and summary Echo runs includes your own Claude instructions, sent to Claude the same way Claude Code sends them when you use it."
          >
            <ClaudeSettings :settings="claude" part="context" />
          </SettingsCard>
        </SettingsSection>

        <SettingsSection v-show="section === 'notifications'" :ref="setSectionRef('notifications')" label="Notifications" @dirty="dirty.notifications = $event">
          <SettingsCard title="Notifications">
            <NotificationSettings :settings="notifications" />
          </SettingsCard>
        </SettingsSection>

        <SettingsSection v-show="section === 'general'" :ref="setSectionRef('general')" label="General" @dirty="dirty.general = $event">
          <SettingsCard title="Time">
            <TimeZoneSetting :time-zone="timeZone" />
          </SettingsCard>
          <SettingsCard title="Appearance">
            <ThemeSetting />
          </SettingsCard>
        </SettingsSection>
      </div>
    </div>
  </AppShell>
</template>
