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
    <div
      v-if="draft.dirty.value"
      class="sticky bottom-4 z-20 flex flex-wrap items-center justify-between gap-3 rounded-[10px] border border-accent/40 bg-surface px-5 py-3 shadow-lg"
      role="region"
      :aria-label="`Unsaved changes in ${label}`"
    >
      <p class="text-[13px] text-muted">Unsaved changes in {{ label }}.</p>
      <div class="flex gap-2">
        <BaseButton :disabled="draft.saving.value" @click="draft.cancel()">Cancel</BaseButton>
        <BaseButton variant="primary" :disabled="draft.saving.value" @click="save">{{ draft.saving.value ? 'Saving…' : 'Save' }}</BaseButton>
      </div>
    </div>
  </div>
</template>
