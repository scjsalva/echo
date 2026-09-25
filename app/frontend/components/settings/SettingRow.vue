<!-- One setting: what it is on the left, its control always on the right. -->
<template>
  <div class="grid gap-x-6 gap-y-2 py-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-center">
    <div class="min-w-0">
      <p class="flex items-center gap-1.5 font-medium"><slot name="title" /></p>
      <p v-if="$slots.description" class="text-[12.5px] text-muted"><slot name="description" /></p>
    </div>
    <div class="flex flex-wrap items-center gap-2 sm:justify-end"><slot /></div>
  </div>
</template>
