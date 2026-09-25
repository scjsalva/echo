<script setup lang="ts">
import { computed, ref } from 'vue'
import { PhCaretRight, PhChatCircle, PhFile, PhFolder, PhFolderOpen } from '@phosphor-icons/vue'
import { buildFileTree, type TreeNode } from '@/lib/fileTree'
import type { DiffFile } from '@/types/dashboard'

const props = defineProps<{ files: DiffFile[]; commentCounts: Record<string, number>; active: string | null }>()
const emit = defineEmits<{ select: [path: string] }>()

const filter = ref('')
const closed = ref(new Set<string>())

const shown = computed(() => {
  const query = filter.value.trim().toLowerCase()
  return query ? props.files.filter((f) => f.path.toLowerCase().includes(query)) : props.files
})
const tree = computed(() => buildFileTree(shown.value))

// Flattened so the list renders without a recursive component.
const rows = computed(() => {
  const out: { node: TreeNode<DiffFile>; depth: number }[] = []
  const walk = (nodes: TreeNode<DiffFile>[], depth: number) =>
    nodes.forEach((node) => {
      out.push({ node, depth })
      if (node.kind === 'dir' && !closed.value.has(node.path)) walk(node.children, depth + 1)
    })
  walk(tree.value, 0)
  return out
})

function toggle(path: string) {
  const next = new Set(closed.value)
  if (!next.delete(path)) next.add(path)
  closed.value = next
}

const STATUS: Record<string, string> = { added: 'text-ok', removed: 'text-bad', renamed: 'text-warn' }
</script>

<template>
  <nav class="grid gap-2" aria-label="Files">
    <div class="flex items-baseline justify-between gap-2">
      <h3 class="text-[11px] font-medium tracking-[0.07em] text-faint uppercase">Files</h3>
      <span class="font-mono text-[11px] text-faint">{{ shown.length }}<template v-if="shown.length !== files.length"> of {{ files.length }}</template></span>
    </div>
    <input
      v-model="filter"
      type="search"
      aria-label="Filter files"
      placeholder="Filter files"
      class="w-full rounded-md border border-line bg-surface px-2.5 py-1.5 text-[13px]"
    />
    <p v-if="!rows.length" class="px-1 text-[12.5px] text-faint">No files match.</p>
    <ul class="grid text-[12.5px]">
      <li v-for="{ node, depth } in rows" :key="node.path">
        <button
          v-if="node.kind === 'dir'"
          type="button"
          class="flex w-full items-center gap-1.5 rounded px-1.5 py-1 text-left text-muted hover:bg-subtle"
          :style="{ paddingLeft: `${depth * 14 + 6}px` }"
          :aria-expanded="!closed.has(node.path)"
          @click="toggle(node.path)"
        >
          <PhCaretRight :size="10" weight="bold" :class="['shrink-0 text-faint transition-transform', !closed.has(node.path) && 'rotate-90']" />
          <component :is="closed.has(node.path) ? PhFolder : PhFolderOpen" :size="14" class="shrink-0 text-faint" />
          <span class="min-w-0 break-all">{{ node.name }}</span>
        </button>
        <button
          v-else
          type="button"
          :class="['flex w-full items-center gap-1.5 rounded px-1.5 py-1 text-left hover:bg-subtle', active === node.path && 'bg-accent-soft text-accent']"
          :style="{ paddingLeft: `${depth * 14 + 22}px` }"
          :aria-current="active === node.path ? 'true' : undefined"
          @click="emit('select', node.path)"
        >
          <PhFile :size="14" :class="['shrink-0', STATUS[node.file.status] ?? 'text-faint']" />
          <span class="min-w-0 break-all">{{ node.name }}</span>
          <span class="ml-auto flex shrink-0 items-center gap-1.5 pl-1 font-mono text-[11px]">
            <span v-if="commentCounts[node.path]" class="flex items-center gap-0.5 text-accent"><PhChatCircle :size="11" weight="fill" />{{ commentCounts[node.path] }}</span>
            <span class="text-ok">+{{ node.file.additions }}</span><span class="text-bad">−{{ node.file.deletions }}</span>
          </span>
        </button>
      </li>
    </ul>
  </nav>
</template>
