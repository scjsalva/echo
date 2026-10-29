import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import JiraAttachments from './JiraAttachments.vue'

const files = [
  { name: 'screen.png', size: 2048, type: 'image/png', author: 'Dana', created: '2026-10-01', url: 'https://acme.atlassian.net/secure/attachment/1/screen.png', thumbnail: 'https://acme.atlassian.net/rest/api/3/attachment/thumbnail/1' },
  { name: 'log.txt', size: 512, type: 'text/plain', author: 'Dana', created: '2026-10-01', url: 'https://acme.atlassian.net/secure/attachment/2/log.txt', thumbnail: null },
]

describe('JiraAttachments', () => {
  it('shows images from Jira, opens each file there, and lists an image that will not load like any other file', async () => {
    const list = mount(JiraAttachments, { props: { files, fallback: 'https://acme.atlassian.net/browse/APP-1' } })

    expect(list.findAll('img')).toHaveLength(1)
    expect(list.findAll('a').map((a) => a.attributes('href'))).toEqual(files.map((f) => f.url))

    await list.find('img').trigger('error')
    expect(list.find('img').exists()).toBe(false)
    expect(list.text()).toContain('screen.png')
  })
})
