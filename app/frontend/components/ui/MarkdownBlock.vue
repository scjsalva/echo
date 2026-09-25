<script setup lang="ts">
import { computed } from 'vue'
import DOMPurify from 'dompurify'
import { marked, Renderer } from 'marked'

const props = defineProps<{ source: string }>()

// Images in private repos need a GitHub login to load, so link to them instead.
const renderer = new Renderer()
renderer.image = ({ href, text }) => `<a href="${href}" target="_blank" rel="noopener">${text || 'Image'} ↗</a>`
renderer.link = ({ href, text }) => `<a href="${href}" target="_blank" rel="noopener">${text}</a>`

// Whatever the description says, only safe HTML reaches the page.
const html = computed(() =>
  DOMPurify.sanitize(marked.parse(props.source, { renderer, gfm: true, breaks: true, async: false }) as string, { ADD_ATTR: ['target'] }),
)
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <div class="markdown break-words" v-html="html" />
</template>
