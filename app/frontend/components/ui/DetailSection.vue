<script setup lang="ts">
defineProps<{ title: string }>()
</script>

<template>
  <section>
    <h4 class="mb-2 text-[11px] font-medium tracking-[0.07em] text-faint uppercase">{{ title }}</h4>
    <slot />
  </section>
</template>
