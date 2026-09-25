import { describe, expect, it } from 'vitest'
import { mount } from '@vue/test-utils'
import ChipListEditor from './ChipListEditor.vue'

const people = Array.from({ length: 15 }, (_, i) => ({ value: `user${i}`, label: i === 12 ? 'Jhonatan Teixeira' : `Person ${i}` }))
const mountEditor = (items: string[] = []) => mount(ChipListEditor, { props: { items, suggestions: people, placeholder: '', label: 'team' } })

describe('ChipListEditor', () => {
  it('shows the top 10 suggestions, then the top 10 matches by value or label', async () => {
    const editor = mountEditor()
    await editor.find('input').trigger('focus')
    expect(editor.findAll('[role="option"]')).toHaveLength(10)

    await editor.find('input').setValue('teix')
    expect(editor.findAll('[role="option"]').map((o) => o.text())).toEqual(['user12Jhonatan Teixeira'])
  })

  it('adds the highlighted match with Enter, and leaves out people already added', async () => {
    const editor = mountEditor(['user0'])
    await editor.find('input').trigger('focus')
    expect(editor.text()).not.toContain('Person 0')

    await editor.find('input').trigger('keydown', { key: 'ArrowDown' })
    await editor.find('form').trigger('submit')

    expect(editor.emitted('change')).toEqual([[['user0', 'user2']]])
  })
})
