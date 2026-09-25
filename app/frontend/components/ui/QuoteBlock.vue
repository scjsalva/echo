<script setup lang="ts">
withDefaults(defineProps<{ accent?: boolean }>(), { accent: false })
</script>

<template>
  <p :class="['max-w-prose border-l-2 py-0.5 pl-3 whitespace-pre-line break-words', accent ? 'border-accent' : 'border-line']"><slot /></p>
</template>
