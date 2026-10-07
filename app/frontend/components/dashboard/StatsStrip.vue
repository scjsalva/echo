<script setup lang="ts">
import { computed } from 'vue'
import StatCount from '@/components/ui/StatCount.vue'
import { formatTokens } from '@/lib/format'
import type { Stats } from '@/types/dashboard'

const props = defineProps<{ stats: Stats }>()

interface Stat {
  label: string
  value: number | string
  tone?: 'default' | 'accent' | 'warn'
  href?: string
  hint?: string
}

const groups = computed<{ title: string; href: string; stats: Stat[] }[]>(() => {
  const { agents, github, jira } = props.stats
  return [
    {
      title: 'Agents',
      href: '/agents',
      stats: [
        { label: 'Agents', value: agents.agents, href: '/agents' },
        { label: 'Busy', value: agents.busy, tone: agents.busy ? 'accent' : 'default', href: '/agents', hint: 'Sessions working on something right now' },
        {
          label: 'Used',
          value: agents.tokensUsed < 1000 ? agents.tokensUsed : formatTokens(agents.tokensUsed),
          href: 'https://claude.ai/settings/usage',
          hint: 'Tokens used today across every session and subagent. Cache reads are left out. Opens your Claude usage.',
        },
      ],
    },
    {
      title: 'Jira',
      href: '/jira',
      stats: [
        jira.boards
          ? { label: 'Unassigned', value: jira.unassigned, href: '/jira?assignee=unassigned', hint: 'Open on your board with nobody assigned, leaving out the Backlog' }
          : { label: 'Unassigned', value: 0, href: '/settings#jira', hint: 'Choose your Jira board in Settings to count tickets nobody has picked up' },
        { label: 'To Do', value: jira.todo, href: '/jira?assignee=me', hint: 'Yours and not started, your Backlog tickets included' },
        { label: 'Done', value: jira.done, href: '/jira?assignee=me', hint: 'Yours and finished in the last 14 days' },
      ],
    },
    {
      title: 'GitHub',
      href: '/github',
      stats: [
        { label: 'Team', value: github.team, tone: github.team ? 'accent' : 'default', href: '/github?tab=team&status=ready', hint: 'PRs from your team that are ready for review' },
        { label: 'Mine', value: github.mine, href: '/github?tab=mine' },
        { label: 'Watching', value: github.watching, href: '/inbox?tab=github', hint: "Other people's PRs you get notifications for" },
      ],
    },
  ]
})

// Each group gets room for its stats plus its own padding and gaps, so every
// stat is the same width whichever group it's in. Matches px-5, gap-4 and the
// 1px divider between groups.
const PADDING = 40
const GAP = 16
const columns = computed(() => {
  const sizes = groups.value.map((g) => g.stats.length)
  const total = sizes.reduce((a, b) => a + b, 0)
  const extra = sizes.map((n, i) => PADDING + (n - 1) * GAP + (i ? 1 : 0))
  const fixed = extra.reduce((a, b) => a + b, 0)
  return sizes.map((n, i) => `calc((100% - ${fixed}px) * ${n / total} + ${extra[i]}px)`).join(' ')
})
</script>

<template>
  <section
    aria-label="Summary"
    class="grid grid-cols-[minmax(0,1fr)] overflow-hidden rounded-xl border border-line bg-surface md:grid-cols-(--stat-columns)"
    :style="{ '--stat-columns': columns }"
  >
    <div
      v-for="group in groups"
      :key="group.title"
      class="grid gap-3 border-line-soft px-5 pt-3.5 pb-4 not-first:border-t md:not-first:border-t-0 md:not-first:border-l"
    >
      <a :href="group.href" class="justify-self-start text-[11px] font-semibold tracking-[0.08em] text-muted uppercase hover:text-accent">
        {{ group.title }}
      </a>
      <div class="grid grid-cols-2 gap-4 sm:grid-flow-col sm:auto-cols-fr sm:grid-cols-none">
        <component
          :is="stat.href ? 'a' : 'div'"
          v-for="stat in group.stats"
          :key="stat.label"
          :href="stat.href"
          :target="stat.href?.startsWith('http') ? '_blank' : undefined"
          :rel="stat.href?.startsWith('http') ? 'noopener' : undefined"
          :class="stat.href && '-m-1.5 rounded-md p-1.5 hover:bg-subtle'"
        >
          <StatCount :value="stat.value" :label="stat.label" :tone="stat.tone" :hint="stat.hint" />
        </component>
      </div>
    </div>
  </section>
</template>
