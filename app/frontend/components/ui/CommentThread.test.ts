import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import CommentThread from './CommentThread.vue'

const at = new Date().toISOString()

describe('CommentThread', () => {
  it('shows a comment expanded by default', () => {
    const item = mount(CommentThread, { props: { author: 'ana', bot: false, at, body: 'Looks good' } })

    expect(item.text()).toContain('ana')
    expect(item.text()).toContain('Looks good')
    expect(item.find('button').exists()).toBe(false)
  })

  it('collapses a bot comment until expanded', async () => {
    const item = mount(CommentThread, { props: { author: 'ci-bot[bot]', bot: true, at, body: 'CI is unhappy' } })

    expect(item.text()).not.toContain('CI is unhappy')
    expect(item.text()).toContain('ci-bot[bot]')

    await item.find('button').trigger('click')

    expect(item.text()).toContain('CI is unhappy')
  })

  it('clamps a long body behind a show more toggle', async () => {
    const body = 'line\n'.repeat(20)
    const item = mount(CommentThread, { props: { author: 'ana', bot: false, at, body } })

    expect(item.find('button').text()).toBe('Show more')

    await item.find('button').trigger('click')

    expect(item.find('button').text()).toBe('Show less')
  })
})
