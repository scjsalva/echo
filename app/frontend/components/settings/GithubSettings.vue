<script setup lang="ts">
import ChipListEditor from './ChipListEditor.vue'
import LocalRepoRow from './LocalRepoRow.vue'
import { useDraftValue, useSettingsDraft } from '@/composables/useSettingsDraft'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { GithubPreferences } from '@/types/dashboard'

const props = defineProps<{ preferences: GithubPreferences }>()

const toast = useToast()
const draft = useSettingsDraft()
const prefs = useDraftValue(props.preferences)

type Change = { github_repos?: string[]; github_team?: string[]; github_local_repo?: { repo: string; path: string } }

// Held until Save; the server's answer then replaces what's shown.
function stage(key: string, change: Change) {
  draft.stage(key, async () => {
    const { github } = await request<{ github: GithubPreferences }>('PATCH', '/api/settings', change)
    prefs.value = github
  })
}

function setRepos(repos: string[]) {
  prefs.value.repos = repos
  stage('github_repos', { github_repos: repos })
}

function setTeam(team: string[]) {
  prefs.value.team = team
  stage('github_team', { github_team: team })
}

function useClone(repo: string, path: string) {
  const entry = prefs.value.localRepos.find((e) => e.repo === repo)
  if (entry) entry.path = path || null
  stage(`local_repo:${repo}`, { github_local_repo: { repo, path } })
}

// Deleting Echo's copy is an action, not a setting, so it happens straight away.
async function removeCopy(repo: string) {
  try {
    await request('DELETE', `/api/github/echo_copy?repo=${encodeURIComponent(repo)}`)
    const entry = prefs.value.localRepos.find((e) => e.repo === repo)
    if (entry) entry.echoCopyBytes = null
    toast.show(`Removed Echo's copy of ${repo}`)
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't remove it")
  }
}
</script>

<template>
  <div class="grid gap-1.5 py-2.5">
    <p class="font-medium">Repos to watch</p>
    <p class="text-[12.5px] text-muted">
      The review queue shows open PRs from these repos.
      {{ prefs.reposChosen ? '' : "Until you change it, it's the repos your own PRs and review requests are in." }}
    </p>
    <ChipListEditor
      :items="prefs.repos"
      :suggestions="prefs.knownRepos"
      placeholder="owner/repo"
      label="watched repos"
      @change="setRepos"
    />
  </div>
  <div class="grid gap-1.5 py-2.5">
    <p class="font-medium">My team</p>
    <p class="text-[12.5px] text-muted">GitHub usernames for the review queue's "My team" filter.</p>
    <ChipListEditor
      :items="prefs.team"
      :suggestions="prefs.knownPeople.map((p) => ({ value: p.login, label: p.name }))"
      placeholder="GitHub username or name"
      label="team"
      @change="setTeam"
    />
  </div>
  <div class="grid gap-1 border-t border-line-soft pt-3">
    <p class="font-medium">Code for AI reviews</p>
    <p class="text-[12.5px] text-muted">
      Claude reads the PR's code to check what it says. Point each repo at a clone you already have, or Echo keeps its own copy.
      Echo never changes your branch or files: it checks the PR out in a separate folder.
    </p>
    <LocalRepoRow
      v-for="entry in prefs.localRepos"
      :key="`${entry.repo}-${entry.path}`"
      :entry="entry"
      @use="(path) => useClone(entry.repo, path)"
      @remove-copy="removeCopy(entry.repo)"
    />
  </div>
</template>
