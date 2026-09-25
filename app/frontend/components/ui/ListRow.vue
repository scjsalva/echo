<script setup lang="ts">
defineProps<{ unread?: boolean }>()
defineEmits<{ select: [] }>()
</script>

<template>
  <button
    type="button"
    class="grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-start gap-3 border-t border-line-soft px-4 py-3 text-left first:border-t-0 hover:bg-subtle"
    @click="$emit('select')"
  >
    <span class="flex min-h-5 items-center"><slot name="lead" /></span>
    <span class="flex min-w-0 flex-col gap-0.5">
      <span class="font-medium text-pretty break-words">
        <span v-if="unread" class="mr-1.5 inline-block size-1.5 rounded-full bg-accent align-middle" aria-label="Unread" />
        <slot />
      </span>
      <span v-if="$slots.content" class="line-clamp-3 text-[13px] text-muted break-words"><slot name="content" /></span>
      <span v-if="$slots.meta" class="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1.5 text-xs text-faint"><slot name="meta" /></span>
    </span>
    <span class="pt-0.5 text-xs whitespace-nowrap text-faint tabular-nums"><slot name="aside" /></span>
  </button>
</template>
