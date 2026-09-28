<script setup lang="ts">
import { watch } from 'vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import { provideSettingsDraft } from '@/composables/useSettingsDraft'
import { useToast } from '@/composables/useToast'

/** One Settings section, with its own Save and Cancel for the changes made in it. */
const props = defineProps<{ label: string }>()
const emit = defineEmits<{ dirty: [value: boolean] }>()

const draft = provideSettingsDraft()
const toast = useToast()
watch(draft.dirty, (value) => emit('dirty', value))

async function save() {
  try {
    await draft.save()
    toast.show(`${props.label} saved`)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't save everything; what's left is still unsaved")
  }
}

defineExpose({ cancel: () => draft.cancel() })
</script>

<template>
  <div class="grid gap-4">
    <slot />
    <!-- Always there, so it's clear where saving happens; it stands out once something's changed. -->
    <div
      :class="[
        'sticky bottom-4 z-20 flex flex-wrap items-center justify-between gap-3 rounded-[10px] border bg-surface px-5 py-3',
        draft.dirty.value ? 'border-accent/40 shadow-lg' : 'border-line',
      ]"
      role="region"
      :aria-label="draft.dirty.value ? `Unsaved changes in ${label}` : `Save ${label}`"
    >
      <p class="text-[13px] text-muted">{{ draft.dirty.value ? `Unsaved changes in ${label}.` : 'No unsaved changes.' }}</p>
      <div class="flex gap-2">
        <BaseButton :disabled="!draft.dirty.value || draft.saving.value" @click="draft.cancel()">Cancel</BaseButton>
        <BaseButton variant="primary" :disabled="!draft.dirty.value || draft.saving.value" @click="save">{{ draft.saving.value ? 'Saving…' : 'Save' }}</BaseButton>
      </div>
    </div>
  </div>
</template>
