import { afterEach, describe, expect, it, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import BaseButton from './BaseButton.vue'

afterEach(() => {
  vi.useRealTimers()
  document.body.innerHTML = ''
})

describe('BaseButton', () => {
  it('shows its tooltip on hover after a short delay', async () => {
    vi.useFakeTimers()
    const button = mount(BaseButton, { props: { tooltip: 'Opens Terminal' }, slots: { default: 'Resume' }, attachTo: document.body })

    await button.find('span').trigger('mouseenter')
    expect(document.body.querySelector('[role="tooltip"]')).toBeNull()
    vi.advanceTimersByTime(300)
    await button.vm.$nextTick()

    expect(document.body.querySelector('[role="tooltip"]')?.textContent).toBe('Opens Terminal')
    await button.find('span').trigger('mouseleave')
    expect(document.body.querySelector('[role="tooltip"]')).toBeNull()
  })

  it('keeps clicks off a button that is not built yet', async () => {
    const onClick = vi.fn()
    const button = mount(BaseButton, { props: { soon: 'Comes later' }, attrs: { onClick }, slots: { default: 'Set up' } })

    await button.find('span').trigger('click')

    expect(onClick).not.toHaveBeenCalled()
    expect(button.find('button').attributes('disabled')).toBeDefined()
  })

  it('passes clicks to an enabled button', async () => {
    const onClick = vi.fn()
    const button = mount(BaseButton, { props: { tooltip: 'Hi' }, attrs: { onClick }, slots: { default: 'Go' } })

    await button.find('button').trigger('click')

    expect(onClick).toHaveBeenCalledOnce()
  })
})
