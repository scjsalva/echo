<script setup lang="ts">
import { computed } from 'vue'
import DOMPurify from 'dompurify'
import { marked, Renderer } from 'marked'

const props = defineProps<{ source: string }>()

// Images pasted into GitHub need a GitHub login to load, so Echo fetches them
// with yours (/api/github/image). Anything else loads as it is.
const GITHUB_ASSET = /^https:\/\/github\.com\/(?:user-attachments\/assets|[\w.-]+\/[\w.-]+\/assets\/\d+)\/[\w-]+$/
const imageSrc = (src: string) => (GITHUB_ASSET.test(src) ? `/api/github/image?${new URLSearchParams({ src })}` : src)

const renderer = new Renderer()
renderer.link = ({ href, text }) => `<a href="${href}" target="_blank" rel="noopener">${text}</a>`

// Whatever the description says, only safe HTML reaches the page. Images,
// whether Markdown or the <img> tags GitHub inserts for screenshots, then load
// lazily, fit the width, and open full size in a new tab when clicked.
const html = computed(() => {
  const safe = DOMPurify.sanitize(marked.parse(props.source, { renderer, gfm: true, breaks: true, async: false }) as string, { ADD_ATTR: ['target'] })
  const page = document.createElement('template')
  page.innerHTML = safe
  for (const img of page.content.querySelectorAll('img')) {
    const original = img.getAttribute('src') ?? ''
    img.setAttribute('src', imageSrc(original))
    img.setAttribute('loading', 'lazy')
    if (img.closest('a')) continue
    const link = document.createElement('a')
    Object.assign(link, { href: original, target: '_blank', rel: 'noopener' })
    img.replaceWith(link)
    link.append(img)
  }
  return page.innerHTML
})
</script>

<template>
  <!-- eslint-disable-next-line vue/no-v-html -->
  <div class="markdown wrap-anywhere" v-html="html" />
</template>
