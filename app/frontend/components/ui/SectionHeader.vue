<script setup lang="ts">
defineProps<{ title: string; meta?: string; href?: string; linkLabel?: string }>()
</script>

<template>
  <div class="mb-2.5 flex flex-wrap items-baseline gap-x-2.5 gap-y-1">
    <h2 class="text-[15px] font-semibold tracking-tight">{{ title }}</h2>
    <span v-if="meta" class="text-[12.5px] text-faint">{{ meta }}</span>
    <a v-if="href" :href="href" class="ml-auto text-[12.5px] font-medium text-accent hover:opacity-80">{{ linkLabel ?? 'See all' }} →</a>
  </div>
</template>
