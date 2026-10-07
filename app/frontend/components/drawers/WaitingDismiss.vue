<script setup lang="ts">
import { ref } from 'vue'
import { PhBellSlash } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { useDashboard } from '@/composables/useDashboard'
import { useDrawer } from '@/composables/useDrawer'
import { useToast } from '@/composables/useToast'
import type { WaitingItem } from '@/types/dashboard'

/** Dismisses the Waiting on you item a drawer was opened from. */
const props = defineProps<{ item: WaitingItem }>()

const dashboard = useDashboard()
const { close } = useDrawer()
const toast = useToast()
const dismissing = ref(false)

async function dismiss() {
  dismissing.value = true
  try {
    await dashboard.dismiss(props.item.key)
    close()
    toast.show('Dismissed. Later activity on this thread only shows in notifications.')
  } catch {
    toast.show("Couldn't dismiss it. Try again.")
  } finally {
    dismissing.value = false
  }
}
</script>

<template>
  <!-- Sits right under the notification it's about, closer than the drawer's usual gap between sections. -->
  <div class="-mt-3 grid justify-items-start gap-1.5">
    <BaseButton size="sm" :disabled="dismissing" @click="dismiss"><PhBellSlash :size="13" /> Dismiss</BaseButton>
    <p class="max-w-prose text-[12.5px] text-faint">
      Waiting on you: {{ item.label.toLowerCase() }}. {{ item.clears }} Dismiss mutes this thread: later activity still reaches your notifications, but it won't come back here.
    </p>
  </div>
</template>
