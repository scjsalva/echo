<script setup lang="ts">
import { computed, ref } from 'vue'
import SettingRow from './SettingRow.vue'
import SkillSelect from './SkillSelect.vue'
import { useDraftValue, useSettingsDraft } from '@/composables/useSettingsDraft'
import { request } from '@/lib/api'
import { PhX } from '@phosphor-icons/vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import type { ClaudeSettings, ContextExtra, ContextFile, SkillAction } from '@/types/dashboard'

// Settings shows the skills and what Claude sees as two cards, one part each.
const props = defineProps<{ settings: ClaudeSettings; part: 'skills' | 'context' }>()

const draft = useSettingsDraft()
const skills = useDraftValue(props.settings.skills)
const reviewLimit = useDraftValue(props.settings.reviewLimit)
const context = useDraftValue(props.settings.context)

const stageLimit = () => draft.stage('ai_review_limit', () => request('PATCH', '/api/settings', { ai_review_limit: reviewLimit.value }))

// Adding extra context: for every run or one repo, a file path or a skill.
const scope = ref<string>('')
const kind = ref<ContextExtra['kind']>('file')
const value = ref('')
const repos = computed(() => context.value.repos.map((r) => r.repo))
const skillOptions = computed(() =>
  scope.value ? (skills.value[0]?.repos.find((r) => r.repo === scope.value)?.options ?? []) : (skills.value[0]?.options ?? []),
)

// Shown straight away; Echo checks each file or skill exists when you Save.
function setExtras(extras: ContextExtra[]) {
  context.value.extras = extras
  draft.stage('context_extras', async () => {
    const result = await request<{ context: ClaudeSettings['context'] }>('PATCH', '/api/claude_context', {
      extras: extras.map(({ kind, value, repo }) => ({ kind, value, repo })),
    })
    context.value = result.context
  })
}

function addExtra() {
  if (!value.value.trim()) return
  setExtras([...context.value.extras, { kind: kind.value, value: value.value.trim(), repo: scope.value || null, found: true }])
  value.value = ''
}

const removeExtra = (extra: ContextExtra) => setExtras(context.value.extras.filter((e) => e !== extra))

function choose(action: SkillAction['action'], skill: string | null, repo?: string) {
  const entry = skills.value.find((a) => a.action === action)
  if (entry) {
    if (repo) {
      const row = entry.repos.find((r) => r.repo === repo)
      if (row) {
        row.override = skill
        row.current = row.options.find((o) => o.id === skill) ?? entry.current
      }
    } else {
      entry.current = entry.options.find((o) => o.id === skill) ?? entry.current
      entry.repos.filter((r) => !r.override).forEach((r) => (r.current = entry.current))
    }
  }
  draft.stage(`skill:${action}:${repo ?? ''}`, async () => {
    skills.value = (await request<{ skills: SkillAction[] }>('PATCH', '/api/skill', { skill_action: action, skill, repo })).skills
  })
}

const size = (files: ContextFile[]) => `${Math.max(1, Math.round(files.reduce((n, f) => n + f.chars, 0) / 1000))}k characters`
</script>

<template>
  <div v-if="part === 'context'" class="grid gap-2 py-3 text-[13px]" aria-label="What Claude sees">
    <p class="text-muted">
      Repo instructions come from your clone (or the default branch of Echo's copy), never from the PR being reviewed.
    </p>
    <div class="grid gap-2 sm:grid-cols-2">
      <div class="grid content-start gap-1">
        <p class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">Always · {{ size(context.global) }}</p>
        <p v-if="!context.global.length" class="text-faint">No ~/.claude/CLAUDE.md</p>
        <p v-for="file in context.global" :key="file.path" class="font-mono text-[12px] break-all">{{ file.path }}</p>
      </div>
      <div v-for="entry in context.repos" :key="entry.repo" class="grid content-start gap-1">
        <p class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">
          For {{ entry.repo }}<template v-if="entry.files.length"> · {{ size(entry.files) }}</template>
        </p>
        <p v-if="!entry.files.length" class="text-faint">No CLAUDE.md found</p>
        <p v-for="file in entry.files" :key="file.path" class="font-mono text-[12px] break-all">{{ file.path }}</p>
      </div>
    </div>

    <div class="grid gap-2 border-t border-line pt-2.5">
      <p class="font-medium">Extra context</p>
      <p class="text-muted">
        Add your own files or skills to go with them. A path starting with ~ or / is used as it is; for a repo, anything else is a path inside your
        clone. A skill added here is reference only: it doesn't change the skill an action uses.
      </p>
      <ul v-if="context.extras.length" class="grid gap-1">
        <li v-for="(extra, i) in context.extras" :key="i" class="flex flex-wrap items-center gap-2 text-[12.5px]">
          <span class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">{{ extra.repo ?? 'All runs' }}</span>
          <span class="text-muted">{{ extra.kind === 'skill' ? 'Skill' : 'File' }}</span>
          <span class="font-mono break-all">{{ extra.value }}</span>
          <span v-if="!extra.found" class="text-warn">Missing, skipped</span>
          <button type="button" class="rounded p-0.5 text-faint hover:bg-surface hover:text-ink" :aria-label="`Remove ${extra.value}`" @click="removeExtra(extra)">
            <PhX :size="12" />
          </button>
        </li>
      </ul>
      <form class="flex flex-wrap items-center gap-2" @submit.prevent="addExtra">
        <select v-model="scope" aria-label="Use it for" class="rounded-md border border-line bg-surface px-2 py-1 text-[12.5px]">
          <option value="">All runs</option>
          <option v-for="repo in repos" :key="repo" :value="repo">{{ repo }}</option>
        </select>
        <select v-model="kind" aria-label="Kind" class="rounded-md border border-line bg-surface px-2 py-1 text-[12.5px]" @change="value = ''">
          <option value="file">File</option>
          <option value="skill">Skill</option>
        </select>
        <input
          v-if="kind === 'file'"
          v-model="value"
          aria-label="File path"
          :placeholder="scope ? 'docs/architecture.md or ~/notes/app.md' : '~/notes/team-conventions.md'"
          class="min-w-48 flex-1 rounded-md border border-line bg-surface px-2 py-1 font-mono text-[12.5px]"
        />
        <SkillSelect v-else :model-value="value || null" :options="skillOptions" label="Skill" inherit-label="Choose a skill" @update:model-value="value = $event ?? ''" />
        <BaseButton size="sm" :disabled="!value.trim()" @click="addExtra">Add</BaseButton>
      </form>
    </div>
  </div>

  <SettingRow v-if="part === 'skills'">
    <template #title>AI reviews at once</template>
    <template #description>Any more wait their turn as Queued, and start when one finishes.</template>
    <select v-model.number="reviewLimit" aria-label="AI reviews at once" class="rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]" @change="stageLimit">
      <option v-for="n in settings.reviewLimitOptions" :key="n" :value="n">{{ n }}</option>
    </select>
  </SettingRow>

  <div v-for="action in part === 'skills' ? skills : []" :key="action.action" class="border-t border-line-soft">
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
