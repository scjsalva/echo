import type { GithubNotification } from '@/types/dashboard'

/**
 * What happened, in words, e.g. "dana approved your PR". Panels that already show
 * who did it pass `withActor: false` to get "approved your PR".
 */
export function githubNotificationText(n: Pick<GithubNotification, 'reason' | 'actor' | 'body' | 'mine'>, { withActor = true } = {}): string {
  const sentence = describe(n)
  return !withActor && n.actor && sentence.startsWith(`${n.actor} `) ? sentence.slice(n.actor.length + 1) : sentence
}

function describe(n: Pick<GithubNotification, 'reason' | 'actor' | 'body' | 'mine'>): string {
  const who = n.actor ?? 'Someone'
  const said = n.body ? `: “${n.body}”` : ''
  // "your PR" only when it's yours; when it isn't, or Echo can't tell, it's "the PR".
  const pr = n.mine ? 'your PR' : 'the PR'
  switch (n.reason) {
    case 'review_requested':
      return `${who} asked you to review`
    case 'approved':
      return `${who} approved ${pr}${said}`
    case 'reviewed':
      return `${who} reviewed ${pr}${said}`
    case 'review_dismissed':
      return `${who}'s review was dismissed`
    case 'changes_requested':
      return `${who} requested changes${said}`
    case 'changes_requested_other':
      return `${who} requested changes on the PR${said}`
    case 'mention':
      return `${who} mentioned you${said}`
    case 'team_mention':
      return `${who} mentioned your team${said}`
    case 'assign':
      return 'You were assigned to the PR'
    case 'ci_activity':
      return 'CI activity on the PR'
    case 'merged':
      return n.actor ? `${n.actor} merged it` : 'It was merged'
    case 'closed':
      return 'It was closed'
    case 'follow_up':
      return `${who} pushed new commits after your review`
    case 'ready_for_review':
      return `${who}'s PR is ready for review`
    default:
      if (n.body) return n.actor ? `${n.actor}: “${n.body}”` : `“${n.body}”`
      return 'New activity on this PR'
  }
}
