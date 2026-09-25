import '@/styles/application.css'
import { createApp, type Component } from 'vue'
import AgentsPage from '@/pages/AgentsPage.vue'
import InboxPage from '@/pages/InboxPage.vue'
import JiraPage from '@/pages/JiraPage.vue'
import LoopsPage from '@/pages/LoopsPage.vue'
import OverviewPage from '@/pages/OverviewPage.vue'
import ReviewPage from '@/pages/ReviewPage.vue'
import GithubPage from '@/pages/GithubPage.vue'
import SettingsPage from '@/pages/SettingsPage.vue'

const pages: Record<string, Component> = { AgentsPage, GithubPage, InboxPage, JiraPage, LoopsPage, OverviewPage, ReviewPage, SettingsPage }

const root = document.querySelector<HTMLElement>('[data-vue-page]')
if (root) {
  const page = pages[root.dataset.vuePage ?? '']
  if (!page) throw new Error(`Unknown page component "${root.dataset.vuePage}"`)
  createApp(page, JSON.parse(root.dataset.props ?? '{}')).mount(root)
}
