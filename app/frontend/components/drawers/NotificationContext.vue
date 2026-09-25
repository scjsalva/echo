<script setup lang="ts">
import UserAvatar from '@/components/ui/UserAvatar.vue'
import { timeAgo } from '@/lib/format'

defineProps<{ label: string; actor: string | null; at: string; text: string; href?: string; hrefLabel?: string }>()
</script>

<template>
  <div class="grid gap-1.5 rounded-lg border border-line px-3 py-2.5">
    <span class="text-[11px] tracking-[0.07em] text-faint uppercase">{{ label }} · {{ timeAgo(at) }} ago</span>
    <p class="flex items-start gap-2">
      <UserAvatar v-if="actor" :name="actor" />
      <span class="whitespace-pre-line break-words"><strong v-if="actor" class="font-medium">{{ actor }}</strong> {{ text }}</span>
    </p>
    <a v-if="href" :href="href" target="_blank" rel="noopener" class="text-[12.5px] text-accent hover:opacity-80">{{ hrefLabel }} ↗</a>
  </div>
</template>
