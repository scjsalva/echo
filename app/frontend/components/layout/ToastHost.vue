<script setup lang="ts">
import { useToast } from '@/composables/useToast'

const { message } = useToast()
</script>

<template>
  <div
    v-if="message"
    role="status"
    class="fixed bottom-5 left-1/2 z-40 -translate-x-1/2 rounded-lg bg-ink px-3.5 py-2 text-[13px] text-canvas shadow-lg"
  >{{ message }}</div>
</template>
