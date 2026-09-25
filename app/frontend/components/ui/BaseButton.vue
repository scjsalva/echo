<script setup lang="ts">
import { computed } from 'vue'
import BaseTooltip from './BaseTooltip.vue'

// Listeners and attributes go on the real control, not the tooltip wrapper, so a
// disabled button stays unclickable.
defineOptions({ inheritAttrs: false })

const props = withDefaults(
  defineProps<{
    variant?: 'primary' | 'secondary'
    size?: 'sm' | 'md'
    href?: string
    disabled?: boolean
    /** Explains what the button does, shown on hover and focus. */
    tooltip?: string
    /** Marks a control whose backend doesn't exist yet; the reason shows as its tooltip. */
    soon?: string
  }>(),
  { variant: 'secondary', size: 'md' },
)

const hint = computed(() => props.soon ?? props.tooltip)
const classes = computed(() => [
  'inline-flex items-center gap-1.5 rounded-md border font-medium transition-colors',
  props.size === 'sm' ? 'px-2 py-0.5 text-xs' : 'px-3 py-1.5 text-[13px]',
  props.variant === 'primary'
    ? 'border-accent bg-accent text-on-accent hover:opacity-90'
    : 'border-line bg-surface text-ink hover:bg-subtle',
  // Disabled buttons swallow mouse events, so let the tooltip wrapper receive them.
  (props.soon || props.disabled) && 'pointer-events-none opacity-50',
])
</script>

<template>
  <component :is="hint ? BaseTooltip : 'span'" :text="hint" class="inline-flex">
    <!-- Links to other sites open in a new tab; links within Echo don't. -->
    <a v-if="href && !soon" v-bind="$attrs" :href="href" :target="href.startsWith('http') ? '_blank' : undefined" rel="noopener" :class="classes"><slot /></a>
    <button v-else v-bind="$attrs" type="button" :class="classes" :disabled="disabled || Boolean(soon)"><slot /></button>
  </component>
</template>
