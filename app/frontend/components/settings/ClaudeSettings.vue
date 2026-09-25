<script setup lang="ts">
import { ref } from 'vue'
import SettingRow from './SettingRow.vue'
import SkillSelect from './SkillSelect.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { ClaudeSettings, ContextFile, SkillAction } from '@/types/dashboard'

const props = defineProps<{ settings: ClaudeSettings }>()

const toast = useToast()
const skills = ref(props.settings.skills)

async function choose(action: SkillAction['action'], skill: string | null, repo?: string) {
  try {
    const result = await request<{ skills: SkillAction[] }>('PATCH', '/api/skill', { skill_action: action, skill, repo })
    skills.value = result.skills
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't save that")
  }
}

const size = (files: ContextFile[]) => `${Math.max(1, Math.round(files.reduce((n, f) => n + f.chars, 0) / 1000))}k characters`
</script>

<template>
  <div class="grid gap-2 rounded-lg bg-subtle px-3.5 py-3 text-[13px]" aria-label="What Claude sees">
    <p class="font-medium">What Echo's Claude runs can see</p>
    <p class="text-muted">
      Every AI review, question and summary Echo runs includes your own Claude instructions, sent to Claude the same way Claude Code sends them when you
      use it. Repo instructions come from your clone (or the default branch of Echo's copy), never from the PR being reviewed.
    </p>
    <div class="grid gap-2 sm:grid-cols-2">
      <div class="grid content-start gap-1">
        <p class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">Always · {{ size(settings.context.global) }}</p>
        <p v-if="!settings.context.global.length" class="text-faint">No ~/.claude/CLAUDE.md</p>
        <p v-for="file in settings.context.global" :key="file.path" class="font-mono text-[12px] break-all">{{ file.path }}</p>
      </div>
      <div v-for="entry in settings.context.repos" :key="entry.repo" class="grid content-start gap-1">
        <p class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">
          For {{ entry.repo }}<template v-if="entry.files.length"> · {{ size(entry.files) }}</template>
        </p>
        <p v-if="!entry.files.length" class="text-faint">No CLAUDE.md found</p>
        <p v-for="file in entry.files" :key="file.path" class="font-mono text-[12px] break-all">{{ file.path }}</p>
      </div>
    </div>
  </div>

  <div v-for="action in skills" :key="action.action" class="border-t border-line-soft first-of-type:border-t-0">
    <SettingRow>
      <template #title>{{ action.label }}</template>
      <template #description>
        {{ action.current.description || action.current.name }}
        <template v-if="action.perRepo"> You can use a different skill for each repo below.</template>
      </template>
      <SkillSelect
        :model-value="action.current.id"
        :options="action.options"
        :label="`Skill for ${action.label}`"
        @update:model-value="choose(action.action, $event)"
      />
    </SettingRow>
    <div v-if="action.perRepo" class="grid gap-1 pb-3 pl-4">
      <div v-for="entry in action.repos" :key="entry.repo" class="flex flex-wrap items-center justify-between gap-2 text-[13px]">
        <span class="font-mono text-[12.5px] text-muted">{{ entry.repo }}</span>
        <SkillSelect
          :model-value="entry.override"
          :options="entry.options"
          :label="`Skill for ${action.label} on ${entry.repo}`"
          inherit-label="Same as above"
          @update:model-value="choose(action.action, $event, entry.repo)"
        />
      </div>
    </div>
  </div>
</template>
