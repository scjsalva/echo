import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import MarkdownEditor from './MarkdownEditor.vue'

describe('MarkdownEditor', () => {
  it('previews what was written as Markdown', async () => {
    const editor = mount(MarkdownEditor, { props: { modelValue: '**Bold** and `code`', 'aria-label': 'Comment' } })

    await editor.findAll('[role="tab"]').find((t) => t.text() === 'Preview')!.trigger('click')

    expect(editor.find('[aria-label="Preview"] strong').text()).toBe('Bold')
    expect(editor.find('[aria-label="Preview"] code').text()).toBe('code')
  })
})
