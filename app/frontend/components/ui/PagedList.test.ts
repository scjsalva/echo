import { describe, expect, it, vi } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { h } from 'vue'
import PagedList from './PagedList.vue'

const pages = [['a', 'b'], ['c']]

function mountList(load: (loaded: string[]) => Promise<{ items: string[]; more: boolean }>) {
  return mount(PagedList<string>, {
    props: { load },
    slots: { default: ({ items }: { items: string[] }) => h('ul', items.map((i) => h('li', i))) },
  })
}

describe('PagedList', () => {
  it('shows the first page, then the next one when Load more is clicked', async () => {
    const load = vi.fn(async (loaded: string[]) => ({ items: pages[loaded.length ? 1 : 0], more: !loaded.length }))
    const list = mountList(load)
    await flushPromises()

    expect(list.findAll('li').map((li) => li.text())).toEqual(['a', 'b'])
    await list.findAll('button').find((b) => b.text() === 'Load more')!.trigger('click')
    await flushPromises()

    expect(load).toHaveBeenLastCalledWith(['a', 'b'])
    expect(list.findAll('li').map((li) => li.text())).toEqual(['a', 'b', 'c'])
    expect(list.text()).not.toContain('Load more')
  })

  it('keeps what was loaded when the parent re-renders with the same reset key', async () => {
    const load = vi.fn(async (loaded: string[]) => ({ items: pages[loaded.length ? 1 : 0], more: !loaded.length }))
    const list = mount(PagedList<string>, {
      props: { load, resetKey: ['open', 'all'], resetDelay: 0 },
      slots: { default: ({ items }: { items: string[] }) => h('ul', items.map((i) => h('li', i))) },
    })
    await flushPromises()
    await list.findAll('button').find((b) => b.text() === 'Load more')!.trigger('click')
    await flushPromises()

    await list.setProps({ resetKey: ['open', 'all'] })
    await flushPromises()
    expect(list.findAll('li')).toHaveLength(3)

    await list.setProps({ resetKey: ['open', 'mine'] })
    await flushPromises()
    expect(list.findAll('li').map((li) => li.text())).toEqual(['a', 'b'])
  })

  it('offers a retry when a page fails', async () => {
    const load = vi.fn().mockRejectedValueOnce(new Error('Jira is down')).mockResolvedValue({ items: ['a'], more: false })
    const list = mountList(load)
    await flushPromises()

    expect(list.text()).toContain('Jira is down')
    await list.findAll('button').find((b) => b.text() === 'Try again')!.trigger('click')
    await flushPromises()

    expect(list.findAll('li').map((li) => li.text())).toEqual(['a'])
  })
})
