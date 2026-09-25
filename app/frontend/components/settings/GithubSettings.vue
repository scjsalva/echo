<script setup lang="ts">
import { ref } from 'vue'
import ChipListEditor from './ChipListEditor.vue'
import LocalRepoRow from './LocalRepoRow.vue'
import { useToast } from '@/composables/useToast'
import { request } from '@/lib/api'
import type { GithubPreferences } from '@/types/dashboard'

const props = defineProps<{ preferences: GithubPreferences }>()

const toast = useToast()
const prefs = ref(props.preferences)

async function save(change: { github_repos?: string[]; github_team?: string[]; github_local_repo?: { repo: string; path: string } }) {
  try {
    const { github } = await request<{ github: GithubPreferences }>('PATCH', '/api/settings', change)
    prefs.value = github
  } catch (error) {
    toast.show(error instanceof Error ? error.message : "Couldn't save that")
  }
}

async function removeCopy(repo: string) {
  try {
    const { github } = await request<{ github: GithubPreferences }>('DELETE', `/api/github/echo_copy?repo=${encodeURIComponent(repo)}`)
    prefs.value = github
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
      @change="save({ github_repos: $event })"
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
      @change="save({ github_team: $event })"
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
      @use="(path) => save({ github_local_repo: { repo: entry.repo, path } })"
      @remove-copy="removeCopy(entry.repo)"
    />
  </div>
</template>
