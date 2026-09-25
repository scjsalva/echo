<script setup lang="ts">
import { ref } from 'vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import SettingRow from './SettingRow.vue'
import type { GithubPreferences } from '@/types/dashboard'

const props = defineProps<{ entry: GithubPreferences['localRepos'][number] }>()
const emit = defineEmits<{ use: [path: string]; removeCopy: [] }>()

const editing = ref(!props.entry.path && !props.entry.suggestions.length)
const path = ref(props.entry.path ?? props.entry.suggestions[0] ?? '')
const confirmingRemove = ref(false)

const size = (bytes: number) => (bytes >= 1024 ** 3 ? `${(bytes / 1024 ** 3).toFixed(1)} GB` : `${Math.max(1, Math.round(bytes / 1024 ** 2))} MB`)

function use(value: string) {
  emit('use', value)
  editing.value = false
}
</script>

<template>
  <SettingRow>
    <template #title><span class="font-mono text-[13px]">{{ entry.repo }}</span></template>
    <template #description>
      <template v-if="entry.path">AI reviews read from your clone at <span class="font-mono">{{ entry.path }}</span>.</template>
      <template v-else-if="entry.echoCopyBytes">AI reviews use Echo's own copy ({{ size(entry.echoCopyBytes) }}).</template>
      <template v-else>Echo downloads its own copy on the first AI review, unless you point it at a clone you have.</template>
      <span v-if="entry.path && entry.echoCopyBytes" class="mt-1.5 flex flex-wrap items-center gap-2 text-ink">
        Echo's own copy ({{ size(entry.echoCopyBytes) }}) isn't needed any more.
        <template v-if="confirmingRemove">
          <BaseButton size="sm" class="border-bad! text-bad!" @click="emit('removeCopy')">Delete it</BaseButton>
          <BaseButton size="sm" @click="confirmingRemove = false">Cancel</BaseButton>
        </template>
        <BaseButton v-else size="sm" @click="confirmingRemove = true">Remove Echo's copy</BaseButton>
      </span>
    </template>

    <form v-if="editing" class="flex flex-wrap items-center gap-2" @submit.prevent="use(path)">
      <input v-model="path" :aria-label="`Clone of ${entry.repo}`" placeholder="~/Projects/repo" class="w-64 rounded-md border border-line bg-surface px-2.5 py-1.5 font-mono text-[12.5px]" />
      <BaseButton variant="primary" :disabled="!path.trim()" @click="use(path)">Use</BaseButton>
      <BaseButton @click="editing = false">Cancel</BaseButton>
    </form>
    <template v-else-if="entry.path">
      <BaseButton @click="editing = true">Change</BaseButton>
      <BaseButton tooltip="AI reviews go back to Echo's own copy" @click="emit('use', '')">Stop using</BaseButton>
    </template>
    <template v-else>
      <BaseButton v-if="entry.suggestions.length" variant="primary" @click="use(entry.suggestions[0])">
        Use <span class="font-mono">{{ entry.suggestions[0] }}</span>
      </BaseButton>
      <BaseButton @click="editing = true">{{ entry.suggestions.length ? 'Other folder' : 'Choose a clone' }}</BaseButton>
    </template>
  </SettingRow>
</template>
