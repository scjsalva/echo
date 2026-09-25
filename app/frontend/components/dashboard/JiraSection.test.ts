import { describe, expect, it } from 'vitest'
import { defineComponent, h } from 'vue'
import { mount } from '@vue/test-utils'
import JiraSection from './JiraSection.vue'
import { provideDashboard } from '@/composables/useDashboard'
import { provideDrawer } from '@/composables/useDrawer'
import type { JiraTicket, PageData } from '@/types/dashboard'

const ticket = (n: number): JiraTicket => ({
  key: `APP-${n}`, url: '', title: `Ticket ${n}`, type: 'Bug', status: 'Backlog', category: 'todo', priority: null as unknown as string,
  assignee: 'Me', reporter: 'Me', sprint: null, description: null, updated: null, assignedToMe: true,
})

function mountSection(tickets: JiraTicket[]) {
  const Host = defineComponent(() => {
    provideDashboard({ shell: {} as PageData['shell'], agents: [], jiraTickets: tickets, jiraNotifications: [] })
    provideDrawer()
    return () => h(JiraSection, { tickets, notifications: [] })
  })
  localStorage.setItem('echo.overview.jira', 'true')
  return mount(Host)
}

describe('JiraSection', () => {
  it('shows three tickets per group and links to the rest', () => {
    const section = mountSection([1, 2, 3, 4, 5].map(ticket))

    expect(section.findAll('button').filter((b) => b.text().startsWith('APP-'))).toHaveLength(3)
    expect(section.find('a[href="/jira"]').text()).toContain('+2 more in to do')
  })

  it('has no more link when a group fits', () => {
    const section = mountSection([1, 2].map(ticket))

    expect(section.text()).not.toContain('more in')
  })
})
