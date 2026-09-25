<script setup lang="ts">
withDefaults(defineProps<{ tone?: 'default' | 'jira' }>(), { tone: 'default' })
</script>

<template>
  <span
    :class="[
      'inline-block rounded border px-1.5 py-px font-mono text-[10px] font-semibold tracking-wide',
      tone === 'jira' ? 'border-jira/40 text-jira' : 'border-line text-muted',
    ]"
  ><slot /></span>
</template>
