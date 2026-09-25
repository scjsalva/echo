<script setup lang="ts">
import { computed } from 'vue'
import SectionHeader from '@/components/ui/SectionHeader.vue'
import PullRequestRow from './PullRequestRow.vue'
import { useNow } from '@/composables/useNow'
import type { PullRequest } from '@/types/dashboard'

const props = defineProps<{ items: PullRequest[]; total: number }>()

const now = useNow(30_000)
const requested = computed(() => props.items.filter((pr) => pr.requestedFromMe).length)
</script>

<template>
  <section>
    <SectionHeader
      title="Review queue"
      :meta="`${total} ready · ${requested} requested from you`"
      href="/github"
    />
    <div class="overflow-hidden rounded-[10px] border border-line bg-surface">
      <p v-if="!items.length" class="px-4 py-5 text-[13px] text-faint">Nothing is ready for review.</p>
      <PullRequestRow v-for="pr in items" :key="pr.key" :pr="pr" :now="now" />
    </div>
  </section>
</template>
