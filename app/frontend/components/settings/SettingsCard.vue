<script setup lang="ts">
defineProps<{ title: string; description?: string }>()
</script>

<template>
  <section class="grid gap-1 rounded-[10px] border border-line bg-surface px-5 pt-4 pb-2 scroll-mt-6">
    <h2 class="text-[14.5px] font-semibold">{{ title }}</h2>
    <p v-if="description" class="max-w-prose text-muted">{{ description }}</p>
    <div class="mt-1 divide-y divide-line-soft"><slot /></div>
  </section>
</template>
