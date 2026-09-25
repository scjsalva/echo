<script setup lang="ts">
import { PhBell, PhGear } from '@phosphor-icons/vue'
import AlertStack from './AlertStack.vue'
import EchoLogo from './EchoLogo.vue'
import FirstRunBanner from './FirstRunBanner.vue'
import ToastHost from './ToastHost.vue'
import { useNow } from '@/composables/useNow'
import { timeAgo } from '@/lib/format'
import type { ShellProps } from '@/types/dashboard'

withDefaults(defineProps<{ shell: ShellProps; title?: string; refreshFailed?: boolean; showFirstRun?: boolean }>(), {
  showFirstRun: true,
})

const now = useNow()
const iconLink = 'inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-[12.5px] text-muted hover:bg-subtle hover:text-ink'
</script>

<template>
  <div class="px-4 pt-4 pb-12 sm:px-7">
    <header class="mb-5 flex flex-wrap items-center gap-3">
      <nav class="mr-auto flex min-w-0 items-center gap-2.5" aria-label="Breadcrumb">
        <a href="/" class="flex items-center gap-2 text-[15px] font-semibold hover:text-accent">
          <EchoLogo />
          Echo
        </a>
        <template v-if="title">
          <span class="text-faint">/</span>
          <h1 class="text-[15px] font-medium text-muted">{{ title }}</h1>
        </template>
      </nav>

      <div class="flex items-center gap-0.5 rounded-lg border border-line bg-surface p-[3px]">
        <span class="relative ml-2 flex size-2" aria-hidden="true">
          <span v-if="!refreshFailed" class="absolute inset-0 rounded-full bg-ok opacity-60 motion-safe:animate-ping" />
          <span :class="['relative size-2 rounded-full', refreshFailed ? 'bg-bad' : 'bg-ok']" />
        </span>
        <span class="px-2 text-[12.5px] whitespace-nowrap text-muted tabular-nums" aria-live="polite">
          {{ refreshFailed ? "Couldn't refresh" : `Updated ${timeAgo(shell.updatedAt, now)} ago` }}
        </span>
        <span class="mx-0.5 h-4 w-px bg-line" aria-hidden="true" />
        <a href="/inbox" :class="iconLink" :aria-label="`Notifications: ${shell.waitingCount} waiting, ${shell.unreadCount} unread`">
          <PhBell :size="15" :weight="shell.unreadCount || shell.waitingCount ? 'fill' : 'regular'" />
          <span v-if="shell.waitingCount" class="rounded-full bg-warn px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ shell.waitingCount }}</span>
          <span v-if="shell.unreadCount" class="rounded-full bg-accent px-1.5 font-mono text-[10.5px] font-semibold text-on-accent">{{ shell.unreadCount }}</span>
        </a>
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
  </div>
</template>
