<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref, watch } from 'vue'
import { PhArrowSquareOut, PhCaretDown, PhCheckCircle, PhGitMerge, PhPaperPlaneTilt, PhSparkle, PhTextAlignLeft, PhWarning } from '@phosphor-icons/vue'
import AppShell from '@/components/layout/AppShell.vue'
import DiffFile from '@/components/review/DiffFile.vue'
import FileTree from '@/components/review/FileTree.vue'
import AiVerdictPopover from '@/components/review/AiVerdictPopover.vue'
import PullRequestComments from '@/components/drawers/PullRequestComments.vue'
import SendReviewDialog from '@/components/review/SendReviewDialog.vue'
import BaseButton from '@/components/ui/BaseButton.vue'
import BasePill from '@/components/ui/BasePill.vue'
import MarkdownBlock from '@/components/ui/MarkdownBlock.vue'
import SideDrawer from '@/components/ui/SideDrawer.vue'
import SkillPicker from '@/components/ui/SkillPicker.vue'
import UserAvatar from '@/components/ui/UserAvatar.vue'
import { useReview } from '@/composables/useReview'
import { useSplitWidth } from '@/composables/useSplitWidth'
import { useToast } from '@/composables/useToast'
import { timeAgo } from '@/lib/format'
import { ci } from '@/lib/labels'
import { request } from '@/lib/api'
import type { ReviewComment, ReviewDraft, ReviewPageProps, ReviewThread } from '@/types/dashboard'

const props = defineProps<ReviewPageProps>()

const toast = useToast()
const { review, starting, startAi, addComment, addAndAsk, updateComment, ask, submit } = useReview(props.review ?? ({ comments: [] } as unknown as ReviewDraft))
const pr = computed(() => props.pullRequest!)
// Ask Claude on each comment shows which skill it uses for this repo.
provide('reviewRepo', computed(() => pr.value && (pr.value.fullName ?? pr.value.key.split('#')[0])))
const sent = computed(() => review.value.status === 'sent')
const merged = computed(() => Boolean(props.mergedAt))
const locked = computed(() => sent.value || merged.value)
const sending = ref(false)

// Claude's verdict on its last run: opens by itself when a run finishes.
const verdict = computed(() => (review.value.aiStatus === 'done' ? (review.value.aiReport ?? null) : null))
const clean = computed(() => verdict.value?.added === 0)
const showVerdict = ref(false)
const summaryDraft = ref('')
const decision = ref<'comment' | 'approve' | 'request_changes'>('comment')

function useVerdictAsSummary() {
  summaryDraft.value = verdict.value?.summary ?? ''
  showVerdict.value = false
  sending.value = true
}
watch(
  () => review.value.aiStatus,
  (now, before) => {
    if (before === 'running' && now === 'done') showVerdict.value = true
  },
)
const dialog = ref<InstanceType<typeof SendReviewDialog>>()
const split = ref<HTMLElement>()
const { width, startDrag, nudge, reset } = useSplitWidth('review.split', split)

const count = (state: ReviewComment['state']) => review.value.comments.filter((c) => c.state === state).length
const commentsFor = (path: string) => review.value.comments.filter((c) => c.path === path)

// Earlier reviews' unresolved threads, by anyone; loaded after the page so it opens fast.
const threads = ref<ReviewThread[]>([])
const threadsFor = (path: string) => threads.value.filter((t) => t.path === path)
onMounted(async () => {
  if (!props.pullRequest) return
  const repo = props.pullRequest.fullName ?? props.pullRequest.key.split('#')[0]
  threads.value = (await request<{ threads: ReviewThread[] }>('GET', `/api/github/pull_requests/${repo}/${props.pullRequest.number}/threads`).catch(() => ({ threads: [] }))).threads
})
const headMoved = computed(() => Boolean(review.value.headSha && props.headSha && review.value.headSha !== props.headSha))
const commentCounts = computed(() => Object.fromEntries((props.files ?? []).map((f) => [f.path, commentsFor(f.path).length])))

const showDescription = ref(false)
const activeFile = ref<string | null>(null)
const diffs = new Map<string, InstanceType<typeof DiffFile>>()
const fileId = (path: string) => `file-${path}`

function selectFile(path: string) {
  activeFile.value = path
  diffs.get(path)?.expand()
  document.getElementById(fileId(path))?.scrollIntoView({ block: 'start' })
}

// Highlights the file at the top of the screen in the tree as you scroll.
let observer: IntersectionObserver | undefined
onMounted(() => {
  if (!('IntersectionObserver' in window)) return
  observer = new IntersectionObserver(
    (entries) => {
      const top = entries.filter((e) => e.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0]
      if (top) activeFile.value = top.target.id.slice('file-'.length)
    },
    { rootMargin: '0px 0px -75% 0px' },
  )
  ;(props.files ?? []).forEach((f) => {
    const el = document.getElementById(fileId(f.path))
    if (el) observer!.observe(el)
  })
})
onBeforeUnmount(() => observer?.disconnect())

async function run<T>(action: () => Promise<T>, failure: string) {
  try {
    return await action()
  } catch (error) {
    toast.show(error instanceof Error ? error.message : failure)
  }
}

async function send(event: 'comment' | 'approve' | 'request_changes', body: string) {
  await run(async () => {
    await submit(event, body)
    sending.value = false
    toast.show('Review sent to GitHub')
  }, "Couldn't send the review")
  dialog.value?.done()
}
</script>

<template>
  <AppShell :shell="shell" title="Review" :show-first-run="false">
    <p v-if="error" class="rounded-xl border border-dashed border-line px-6 py-10 text-muted">Couldn't load this pull request: {{ error }}</p>

    <template v-else>
      <header class="mb-5 grid gap-3 border-b border-line pb-4" aria-label="Pull request">
        <div class="flex flex-wrap items-start justify-between gap-x-6 gap-y-3">
          <div class="grid min-w-0 gap-1.5">
            <div class="flex flex-wrap items-center gap-2">
              <span class="font-mono text-xs text-faint">{{ pr.repo }}#{{ pr.number }}</span>
              <BasePill :tone="ci[pr.ci].tone">{{ ci[pr.ci].label }}</BasePill>
              <BasePill v-if="pr.draft">Draft</BasePill>
              <BasePill v-if="merged" tone="accent">Merged</BasePill>
            </div>
            <h1 class="text-lg font-semibold text-balance">{{ pr.title }}</h1>
            <p class="flex flex-wrap items-center gap-2 text-[13px] text-muted">
              <UserAvatar :name="pr.author" /> {{ pr.author }} · <span class="font-mono"><span class="text-ok">+{{ pr.additions }}</span> <span class="text-bad">−{{ pr.deletions }}</span></span> · {{ pr.changedFiles }} files
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <BaseButton :aria-pressed="showDescription" :class="showDescription && 'border-accent! bg-accent-soft! text-accent!'" @click="showDescription = !showDescription">
              <PhTextAlignLeft :size="14" /> Description
            </BaseButton>
            <BaseButton :href="pr.url">Open on GitHub <PhArrowSquareOut :size="14" /></BaseButton>
            <template v-if="!locked">
              <div class="relative flex">
                <BaseButton
                  :disabled="starting || review.aiStatus === 'running' || review.aiStatus === 'queued'"
                  tooltip="Claude reviews the diff and stages comments. Uses tokens."
                  :class="[verdict && 'rounded-r-none', clean ? 'border-ok! bg-ok-soft! text-ok!' : 'ai-border']"
                  @click="run(startAi, 'Couldn\'t start the review')"
                >
                  <component :is="clean ? PhCheckCircle : PhSparkle" :size="14" weight="fill" :class="!clean && 'ai-icon'" />
                  <span :class="!clean && 'ai-text'">{{ starting ? 'Starting…' : review.aiStatus === 'queued' ? 'Queued…' : review.aiStatus === 'running' ? 'Reviewing…' : review.aiStatus === 'idle' ? 'Start AI review' : 'Review again' }}</span>
                </BaseButton>
                <template v-if="verdict">
                  <BaseButton
                    aria-label="Claude's verdict"
                    :aria-expanded="showVerdict"
                    :class="['-ml-px rounded-l-none px-2!', clean ? 'border-ok! bg-ok-soft! text-ok!' : 'ai-border']"
                    @click="showVerdict = !showVerdict"
                  >
                    <PhCaretDown :size="12" weight="bold" />
                  </BaseButton>
                  <AiVerdictPopover v-if="showVerdict" :report="verdict" @close="showVerdict = false" @use-as-summary="useVerdictAsSummary" />
                </template>
              </div>
              <div class="relative">
                <BaseButton variant="primary" :aria-expanded="sending" @click="sending = !sending">
                  <PhPaperPlaneTilt :size="14" /> Send review <PhCaretDown :size="12" weight="bold" />
                </BaseButton>
                <SendReviewDialog
                  v-if="sending"
                  ref="dialog"
                  :committed="count('committed')"
                  :staged="count('staged')"
                  :own-pr="pr.mine"
                  v-model:body="summaryDraft"
                  v-model:event="decision"
                  @send="send"
                  @cancel="sending = false"
                />
              </div>
            </template>
          </div>
        </div>

        <p v-if="merged && !sent" class="flex items-center gap-1.5 text-[13px] text-muted">
          <PhGitMerge :size="14" class="text-accent" /> Merged {{ timeAgo(mergedAt!) }} ago, so it can't be reviewed any more.
        </p>
        <p v-else-if="locked" class="text-[13px] text-muted">
          Sent to GitHub.
          <a v-if="review.githubUrl" :href="review.githubUrl" target="_blank" rel="noopener" class="text-accent hover:opacity-80">See it on GitHub ↗</a>
        </p>
        <div v-else class="flex flex-wrap items-center gap-x-3 gap-y-2 text-[13px] text-muted" aria-label="Your review">
          <span class="flex gap-2 text-[12.5px]">
            <BasePill>{{ count('staged') }} staged</BasePill>
            <BasePill tone="ok">{{ count('committed') }} committed</BasePill>
          </span>
          <span>
            <template v-if="review.aiStatus === 'queued'">Queued: the most AI reviews that can run at once are running. This one starts when one finishes.</template>
            <template v-else-if="review.aiStatus === 'running'">Claude is reading the diff. Its comments appear on the lines as staged.</template>
            <template v-else-if="review.aiStatus === 'failed'"><span class="text-bad">The AI review didn't finish: {{ review.aiError }}</span></template>
            <template v-else-if="review.aiStatus === 'done' && !review.aiReport">Claude's done. Commit the comments you want to keep; nothing is posted until you send the review.</template>
            <template v-else-if="review.aiStatus === 'done'">Commit the comments you want to keep; nothing is posted until you send the review.</template>
            <template v-else>Let Claude look for problems, or add your own comments with the + on any line. Nothing is posted until you send the review.</template>
          </span>
          <SkillPicker action="ai_review" :repo="pr.fullName ?? pr.key.split('#')[0]" class="ml-auto" />
          <span v-if="headMoved" class="flex basis-full items-start gap-1.5 text-[12.5px] text-warn">
            <PhWarning :size="14" class="mt-0.5 shrink-0" /> New commits were pushed since this review started, so some comments may point at old lines.
          </span>
        </div>
      </header>

      <div ref="split" class="review-split grid items-start gap-6 lg:gap-0" :style="{ '--left': `${width}px` }">
        <aside class="grid min-w-0 gap-4 overflow-x-hidden lg:sticky lg:top-4 lg:max-h-[calc(100vh-2rem)] lg:overflow-y-auto lg:pr-1 [&>*]:min-w-0">
          <FileTree :files="files ?? []" :comment-counts="commentCounts" :active="activeFile" @select="selectFile" />
        </aside>

        <div
          role="separator"
          aria-orientation="vertical"
          aria-label="Resize the panels"
          :aria-valuenow="width"
          tabindex="0"
          title="Drag to resize. Double-click to reset."
          class="group sticky top-4 hidden h-[calc(100vh-2rem)] cursor-col-resize touch-none justify-center focus:outline-none lg:flex"
          @pointerdown="startDrag"
          @dblclick="reset"
          @keydown.left.prevent="nudge(-24)"
          @keydown.right.prevent="nudge(24)"
        >
          <span class="h-full w-px bg-line transition-colors group-hover:w-0.5 group-hover:bg-accent group-focus-visible:w-0.5 group-focus-visible:bg-accent" />
        </div>

        <main class="grid min-w-0 gap-4" aria-label="Changes">
          <DiffFile
            v-for="file in files"
            :id="fileId(file.path)"
            :key="file.path"
            :ref="(el) => (el ? diffs.set(file.path, el as InstanceType<typeof DiffFile>) : diffs.delete(file.path))"
            class="scroll-mt-4"
            :file="file"
            :comments="commentsFor(file.path)"
            :threads="threadsFor(file.path)"
            :locked="locked"
            @add="(fields) => run(() => addComment(fields), 'Couldn\'t add the comment')"
            @update="(id, fields) => run(() => updateComment(id, fields), 'Couldn\'t update the comment')"
            @ask="(id, q) => run(() => ask(id, q), 'Couldn\'t ask Claude')"
            @add-and-ask="(fields, q) => run(() => addAndAsk(fields, q), 'Couldn\'t ask Claude')"
          />
        </main>
      </div>
    </template>

    <SideDrawer v-if="showDescription" label="Description" side="left" @close="showDescription = false">
      <template #eyebrow><span class="font-mono text-xs text-faint">{{ pr.repo }}#{{ pr.number }}</span></template>
      <template #title>{{ pr.title }}</template>
      <MarkdownBlock v-if="pr.description" :source="pr.description" />
      <p v-else class="text-[13px] text-faint">No description.</p>
      <PullRequestComments :repo="pr.fullName ?? pr.key.split('#')[0]" :number="pr.number" />
    </SideDrawer>
  </AppShell>
</template>

<style scoped>
@media (width >= 64rem) {
  .review-split {
    grid-template-columns: var(--left) 1.5rem minmax(0, 1fr);
  }
}
</style>
