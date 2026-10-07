<script setup lang="ts">
// A notification popup tints it by where the notification came from; everywhere else it's Echo's own colour.
const props = defineProps<{ source?: 'agent' | 'github' | 'jira' }>()
const FILL = { agent: 'fill-agent', github: 'fill-github', jira: 'fill-jira' } as const
</script>

<template>
  <svg viewBox="0 0 32 32" class="size-[20px] shrink-0" aria-hidden="true">
    <rect width="32" height="32" rx="8" :class="props.source ? FILL[props.source] : 'fill-accent'" />
    <circle cx="11" cy="16" r="3" :class="props.source ? 'fill-white' : 'fill-on-accent'" />
    <path d="M16.5 10.5a7.78 7.78 0 0 1 0 11" fill="none" :class="props.source ? 'stroke-white' : 'stroke-on-accent'" stroke-width="2.6" stroke-linecap="round" />
    <path d="M20 7a12.73 12.73 0 0 1 0 18" fill="none" :class="props.source ? 'stroke-white' : 'stroke-on-accent'" stroke-opacity=".55" stroke-width="2.6" stroke-linecap="round" />
  </svg>
</template>
