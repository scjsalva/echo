import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import MarkdownBlock from './MarkdownBlock.vue'

describe('MarkdownBlock', () => {
  it('renders headings, checklists and code', () => {
    const block = mount(MarkdownBlock, { props: { source: '## What\n\n- [x] Tests\n- [ ] Docs\n\nRun `bin/dev`.' } })

    expect(block.find('h2').text()).toBe('What')
    expect(block.findAll('li')).toHaveLength(2)
    expect(block.find('code').text()).toBe('bin/dev')
  })

  it('links images instead of loading them and strips anything unsafe', () => {
    const block = mount(MarkdownBlock, {
      props: { source: '![screenshot](https://github.com/x.png)\n\n<img src=x onerror="alert(1)"><script>alert(2)</script>[click](javascript:alert(3))' },
    })

    expect(block.find('a[href="https://github.com/x.png"]').text()).toContain('screenshot')
    expect(block.html()).not.toContain('onerror')
    expect(block.html()).not.toContain('<script')
    expect(block.html()).not.toContain('javascript:')
  })
})
