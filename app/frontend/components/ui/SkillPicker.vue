<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { PhGearSix } from '@phosphor-icons/vue'
import SkillSelect from '@/components/settings/SkillSelect.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { SkillAction, SkillChoice, SkillOption } from '@/types/dashboard'

/** Which skill an action runs with, and a quick way to change it. For a repo, the change applies to that repo only. */
const props = defineProps<{ action: SkillAction['action']; repo?: string }>()

const toast = useToast()
const current = ref<SkillOption | null>(null)
const options = ref<SkillOption[]>([])
const override = ref<string | null>(null)
const open = ref(false)
const root = ref<HTMLElement>()

async function load() {
  const data = await request<SkillChoice | SkillAction>('GET', `/api/skill?${new URLSearchParams({ skill_action: props.action, ...(props.repo ? { repo: props.repo } : {}) })}`)
  current.value = data.current
  options.value = data.options
  override.value = 'override' in data ? data.override : data.current.id
}

async function choose(skill: string | null) {
  try {
    await request('PATCH', '/api/skill', { skill_action: props.action, skill, repo: props.repo })
    await load()
    open.value = false
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't change the skill")
  }
}

const onKey = (e: KeyboardEvent) => e.key === 'Escape' && (open.value = false)
const onPointer = (e: PointerEvent) => !root.value?.contains(e.target as Node) && (open.value = false)
watch(open, (isOpen) => {
  if (isOpen) {
    document.addEventListener('keydown', onKey)
    document.addEventListener('pointerdown', onPointer)
  } else {
    document.removeEventListener('keydown', onKey)
    document.removeEventListener('pointerdown', onPointer)
  }
})
onMounted(() => load().catch(() => null))
onBeforeUnmount(() => (open.value = false))
</script>

<template>
  <span v-if="current" ref="root" class="relative inline-flex items-center gap-1 text-[11.5px] whitespace-nowrap text-faint">
    Skill: <span class="font-mono text-muted">{{ current.name }}</span>
    <button type="button" class="rounded p-0.5 hover:bg-subtle hover:text-ink" :aria-label="`Change the skill`" :aria-expanded="open" @click="open = !open">
      <PhGearSix :size="13" />
    </button>
    <div
      v-if="open"
      role="dialog"
      aria-label="Choose a skill"
      class="absolute top-full right-0 z-30 mt-2 grid w-72 gap-2 whitespace-normal rounded-lg border border-line bg-surface p-3 text-left text-[12.5px] text-ink shadow-xl"
    >
      <p class="text-muted">{{ repo ? `Used for ${repo} only.` : 'Used everywhere.' }} Echo's rules for this action still apply.</p>
      <SkillSelect
        :model-value="override"
        :options="options"
        label="Skill"
        :inherit-label="repo ? 'Same as in Settings' : undefined"
        @update:model-value="choose"
      />
      <p v-if="current.description" class="text-faint">{{ current.description }}</p>
      <a href="/settings#skills" class="text-accent hover:opacity-80">All skills in Settings</a>
    </div>
  </span>
</template>
