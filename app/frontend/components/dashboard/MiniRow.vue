<script setup lang="ts">
defineEmits<{ select: [] }>()
</script>

<template>
  <button
    type="button"
    class="-mx-2 grid w-[calc(100%+1rem)] grid-cols-[auto_minmax(0,1fr)] items-start gap-2.5 rounded-md px-2 py-1.5 text-left hover:bg-subtle"
    @click="$emit('select')"
  >
    <span class="flex min-h-5 items-center"><slot name="lead" /></span>
    <span class="flex min-w-0 flex-col">
      <span class="text-[13px] font-medium break-words"><slot /></span>
      <span v-if="$slots.sub" class="line-clamp-3 text-[12.5px] text-muted break-words"><slot name="sub" /></span>
    </span>
  </button>
</template>
