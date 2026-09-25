<script setup lang="ts">
import { PhInfo } from '@phosphor-icons/vue'
import BaseTooltip from './BaseTooltip.vue'

defineProps<{ text: string }>()
</script>

<template>
  <BaseTooltip :text="text" class="align-middle">
    <button type="button" class="inline-flex rounded-full text-faint hover:text-muted" aria-label="More info" @click.stop>
      <PhInfo :size="13" weight="bold" />
    </button>
  </BaseTooltip>
</template>
