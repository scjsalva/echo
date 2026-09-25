<script setup lang="ts">
import { computed } from 'vue'
import { PhPlugs } from '@phosphor-icons/vue'

const props = defineProps<{ missing: string[] }>()

const names = computed(() => new Intl.ListFormat('en', { type: 'conjunction' }).format(props.missing))
</script>

<template>
  <section class="mb-6 flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-accent/30 bg-accent-soft px-4 py-3">
    <PhPlugs :size="20" weight="duotone" class="text-accent" />
    <p class="min-w-0 flex-1 text-[13.5px]">
      <strong class="font-semibold">{{ names }} {{ missing.length > 1 ? "aren't" : "isn't" }} connected yet.</strong>
      Connect {{ missing.length > 1 ? 'them' : 'it' }} to fill in the rest of this page.
    </p>
    <a href="/settings#connections" class="text-[13px] font-medium text-accent hover:opacity-80">Set up connections →</a>
  </section>
</template>
