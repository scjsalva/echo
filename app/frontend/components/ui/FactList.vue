<script setup lang="ts">
defineProps<{ facts: { label: string; value: string | number }[] }>()
</script>

<template>
  <dl class="flex flex-wrap gap-x-5 gap-y-2 text-[12.5px] text-muted">
    <div v-for="fact in facts" :key="fact.label" class="flex items-baseline gap-1.5">
      <dt>{{ fact.label }}</dt>
      <dd class="font-mono text-[13px] font-medium text-ink">{{ fact.value }}</dd>
    </div>
  </dl>
</template>
