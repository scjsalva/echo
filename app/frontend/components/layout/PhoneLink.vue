<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { PhDeviceMobile } from '@phosphor-icons/vue'
import QRCode from 'qrcode'

const props = defineProps<{ lanIp: string; linkClass: string }>()

const open = ref(false)
const svg = ref('')
// The page you're on, at the Mac's network address rather than localhost.
const url = computed(() => `${location.protocol}//${props.lanIp}${location.port ? `:${location.port}` : ''}${location.pathname}${location.search}`)


watch([open, url], async ([isOpen]) => {
  if (isOpen) svg.value = await QRCode.toString(url.value, { type: 'svg', margin: 1 })
})
</script>

<template>
  <div class="sm:relative" @mouseenter="open = true" @mouseleave="open = false" @focusin="open = true" @focusout="open = false" @keydown.esc="open = false">
    <button type="button" :class="linkClass" aria-label="Open on your phone" :aria-expanded="open">
      <PhDeviceMobile :size="15" />
    </button>
    <div
      v-if="open"
      role="dialog"
      aria-label="Open on your phone"
      class="absolute top-full right-0 z-30 mt-2 grid w-64 before:absolute before:inset-x-0 before:-top-2 before:h-2 justify-items-center gap-3 rounded-lg border border-line bg-surface p-4 text-center shadow-xl"
    >
      <div class="w-full rounded-md bg-white p-2 [&>svg]:h-auto [&>svg]:w-full" v-html="svg" />
      <p class="text-[12.5px] text-muted">Scan with a phone on the same Wi-Fi to open this page there.</p>
      <p class="font-mono text-[11.5px] break-all text-faint">{{ url }}</p>
    </div>
  </div>
</template>
