import type { CiState, GithubReason, JiraCategory, JiraKind, PullRequest } from '@/types/dashboard'

export type Tone = 'neutral' | 'accent' | 'ok' | 'warn' | 'bad'

export const githubReason: Record<GithubReason, { label: string; tone: Tone }> = {
  review_requested: { label: 'Review request', tone: 'accent' },
  mention: { label: 'Mention', tone: 'warn' },
  comment: { label: 'Comment', tone: 'neutral' },
  follow_up: { label: 'New commits', tone: 'accent' },
  ready_for_review: { label: 'Ready for review', tone: 'accent' },
  changes_requested: { label: 'Changes requested', tone: 'bad' },
  changes_requested_other: { label: 'Changes requested', tone: 'neutral' },
  ci_activity: { label: 'CI', tone: 'neutral' },
  team_mention: { label: 'Team mention', tone: 'warn' },
  author: { label: 'Activity', tone: 'neutral' },
  assign: { label: 'Assigned', tone: 'accent' },
  state_change: { label: 'State change', tone: 'neutral' },
  subscribed: { label: 'Watching', tone: 'neutral' },
  manual: { label: 'Subscribed', tone: 'neutral' },
  approved: { label: 'Approved', tone: 'ok' },
  reviewed: { label: 'Reviewed', tone: 'accent' },
  review_dismissed: { label: 'Review dismissed', tone: 'neutral' },
  merged: { label: 'Merged', tone: 'ok' },
  closed: { label: 'Closed', tone: 'neutral' },
}

export const jiraKind: Record<JiraKind, { label: string; tone: Tone }> = {
  mention: { label: 'Mention', tone: 'warn' },
  comment: { label: 'Comment', tone: 'neutral' },
  transition: { label: 'Status', tone: 'neutral' },
  assigned: { label: 'Assigned', tone: 'accent' },
}

export const ci: Record<CiState, { label: string; tone: Tone }> = {
  passing: { label: 'CI passing', tone: 'ok' },
  failing: { label: 'CI failing', tone: 'bad' },
  running: { label: 'CI running', tone: 'warn' },
}

export function reviewStatus(pr: PullRequest): { label: string; tone: Tone } {
  switch (pr.reviewState) {
    case 'approved':
      return { label: 'Approved', tone: 'ok' }
    case 'changes_requested':
      return { label: 'Changes requested', tone: 'bad' }
    case 'draft':
      return { label: 'Draft', tone: 'neutral' }
    default:
      return pr.approvalsRequired
        ? { label: `${pr.approvals ?? 0} of ${pr.approvalsRequired} approvals`, tone: 'warn' }
        : { label: 'Review required', tone: 'warn' }
  }
}

export const JIRA_GROUP_TITLES: Record<JiraCategory, string> = {
  todo: 'To do',
  in_progress: 'In progress',
  code_review: 'Code review',
  post_development: 'Post development',
  done: 'Done',
}
