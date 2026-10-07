<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref } from 'vue'
import { PhCoffee, PhGear } from '@phosphor-icons/vue'
import BaseTooltip from '@/components/ui/BaseTooltip.vue'
import AlertStack from './AlertStack.vue'
import LinkedDrawer from './LinkedDrawer.vue'
import NotificationMenu from './NotificationMenu.vue'
import PhoneLink from './PhoneLink.vue'
import HealthStatus from './HealthStatus.vue'
import EchoLogo from './EchoLogo.vue'
import FirstRunBanner from './FirstRunBanner.vue'
import ToastHost from './ToastHost.vue'
import WakeOverlay from './WakeOverlay.vue'
import { useOptionalDashboard } from '@/composables/useDashboard'
import { useNotificationLink } from '@/composables/useNotificationLink'
import { request } from '@/lib/api'
import type { ShellProps } from '@/types/dashboard'

const props = withDefaults(defineProps<{
  shell: ShellProps
  title?: string
  /** Pages between Echo and this one, e.g. GitHub for a PR's review page. */
  trail?: { label: string; href: string }[]
  refreshFailed?: boolean
  showFirstRun?: boolean
  /** The page fills the screen itself (the Jira board), so only a little room is left below it. */
  fill?: boolean
}>(), {
  trail: () => [],
  showFirstRun: true,
})


// The header's counts. Pages with a dashboard keep them fresh; the others
// (Settings, a review) follow changes here, so the bell never needs a reload.
const dashboard = useOptionalDashboard()
const ownShell = ref<ShellProps | null>(null)
const shell = computed(() => ownShell.value ?? props.shell)
async function refreshShell() {
  if (dashboard) return dashboard.refresh()
  ownShell.value = (await request<{ shell: ShellProps }>('GET', '/api/changes?shell=1').catch(() => null))?.shell ?? ownShell.value
}
provide('refreshShell', refreshShell)
const CHANGES_MS = 5_000
let seen: number | null = null
const followChanges = dashboard
  ? undefined
  : setInterval(async () => {
      if (document.visibilityState !== 'visible') return
      const { version } = await request<{ version: number }>('GET', '/api/changes').catch(() => ({ version: seen ?? 0 }))
      if (seen !== null && version !== seen) refreshShell()
      seen = version
    }, CHANGES_MS)
onBeforeUnmount(() => clearInterval(followChanges))

// Clicking an OS notification sets #echo-open=<link> on an open Echo tab rather
// than loading the link, so the item opens in a drawer over whatever page you're on.
const { linked, openLink, close } = useNotificationLink()
const LINK_HASH = '#echo-open='
function openFromHash() {
  if (!location.hash.startsWith(LINK_HASH)) return
  const link = decodeURIComponent(location.hash.slice(LINK_HASH.length))
  history.replaceState(null, '', `${location.pathname}${location.search}`)
  openLink(link)
}
onMounted(() => {
  openFromHash()
  window.addEventListener('hashchange', openFromHash)
})
onBeforeUnmount(() => window.removeEventListener('hashchange', openFromHash))
const fallback = (target: NonNullable<typeof linked.value>) =>
  target.type === 'agent'
    ? `/agents?agent=${encodeURIComponent(target.id)}`
    : `/${target.type === 'pullRequest' ? 'github?pr' : 'jira?ticket'}=${encodeURIComponent(target.key)}${target.notificationId ? `&notification=${encodeURIComponent(target.notificationId)}` : ''}`
// The QR code is for getting from the Mac to a phone, so it's left off a page opened on a phone or another device.
const onThisMac = ['localhost', '127.0.0.1', '[::1]'].includes(location.hostname)
const iconLink = 'inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-[12.5px] text-muted hover:bg-subtle hover:text-ink'
</script>

<template>
  <div :class="['px-4 pt-4 sm:px-7', fill ? 'pb-4' : 'pb-12']">
    <!-- On phones the header's menus anchor here, to the screen's right edge, rather than to their own buttons,
         which can wrap anywhere. -->
    <header class="relative mb-5 flex flex-wrap items-center gap-3">
      <nav class="mr-auto flex min-w-0 items-center gap-2.5" aria-label="Breadcrumb">
        <a href="/" class="flex items-center gap-2 text-[15px] font-semibold hover:text-accent">
          <EchoLogo />
          Echo
        </a>
        <template v-for="crumb in trail" :key="crumb.href">
          <span class="text-faint">/</span>
          <a :href="crumb.href" class="text-[15px] font-medium text-muted hover:text-accent">{{ crumb.label }}</a>
        </template>
        <template v-if="title">
          <span class="text-faint">/</span>
          <h1 class="text-[15px] font-medium text-muted">{{ title }}</h1>
        </template>
      </nav>

      <div class="flex items-center gap-0.5 rounded-lg border border-line bg-surface p-[3px] sm:relative">
        <HealthStatus :updated-at="shell.updatedAt" :refresh-failed="refreshFailed" />
        <BaseTooltip v-if="shell.keepAwake" :text="`Keeping the computer awake: ${shell.keepAwake}. Change it in Settings → General.`" placement="bottom">
          <a href="/settings#general" class="flex size-7 items-center justify-center rounded-md text-accent hover:bg-subtle" aria-label="Keeping the computer awake">
            <PhCoffee :size="15" />
          </a>
        </BaseTooltip>
        <span class="mx-0.5 h-4 w-px bg-line" aria-hidden="true" />
        <PhoneLink v-if="shell.lanIp && onThisMac" :lan-ip="shell.lanIp" :link-class="iconLink" />
        <NotificationMenu :shell="shell" :link-class="iconLink" />
        <a href="/settings" :class="iconLink" aria-label="Settings">
          <PhGear :size="15" />
          <span class="hidden sm:inline">Settings</span>
        </a>
      </div>
    </header>

    <FirstRunBanner v-if="showFirstRun && shell.missingConnections.length" :missing="shell.missingConnections" />
    <slot />
    <ToastHost />
    <AlertStack />
    <WakeOverlay />
    <LinkedDrawer v-if="linked" :key="JSON.stringify(linked)" :target="linked" :fallback="fallback(linked)" @closed="close" />
  </div>
</template>
