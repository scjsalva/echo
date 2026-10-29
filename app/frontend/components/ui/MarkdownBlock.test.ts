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

  it('shows images, fetching GitHub ones through Echo, and strips anything unsafe', () => {
    const asset = 'https://github.com/user-attachments/assets/b15d8e65-bea7-4469-b654-7bb960c7c2ea'
    const block = mount(MarkdownBlock, {
      props: {
        source: `![badge](https://example.com/badge.svg)\n\n<img alt="screenshot" src="${asset}" />\n\n` +
          '<img src=x onerror="alert(1)"><script>alert(2)</script>[click](javascript:alert(3))',
      },
    })

    expect(block.find('img[alt="badge"]').attributes('src')).toBe('https://example.com/badge.svg')
    const screenshot = block.find('img[alt="screenshot"]')
    expect(screenshot.attributes('src')).toBe(`/api/github/image?${new URLSearchParams({ src: asset })}`)
    expect(screenshot.element.parentElement!.getAttribute('href'), 'opens full size').toBe(asset)
    expect(block.html()).not.toContain('onerror')
    expect(block.html()).not.toContain('<script')
    expect(block.html()).not.toContain('javascript:')
  })
})
