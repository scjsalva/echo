import type { GithubNotification } from '@/types/dashboard'

/**
 * What happened, in words, e.g. "dana approved your PR". Panels that already show
 * who did it pass `withActor: false` to get "approved your PR".
 */
export function githubNotificationText(n: Pick<GithubNotification, 'reason' | 'actor' | 'body'>, { withActor = true } = {}): string {
  const sentence = describe(n)
  return !withActor && n.actor && sentence.startsWith(`${n.actor} `) ? sentence.slice(n.actor.length + 1) : sentence
}

function describe(n: Pick<GithubNotification, 'reason' | 'actor' | 'body'>): string {
  const who = n.actor ?? 'Someone'
  const said = n.body ? `: “${n.body}”` : ''
  switch (n.reason) {
    case 'review_requested':
      return `${who} asked you to review`
    case 'approved':
      return `${who} approved your PR${said}`
    case 'reviewed':
      return `${who} reviewed your PR${said}`
    case 'review_dismissed':
      return `${who}'s review was dismissed`
    case 'changes_requested':
      return `${who} requested changes${said}`
    case 'merged':
      return n.actor ? `${n.actor} merged it` : 'It was merged'
    case 'closed':
      return 'It was closed'
    case 'follow_up':
      return `${who} pushed new commits after your review`
    default:
      if (n.body) return n.actor ? `${n.actor}: “${n.body}”` : `“${n.body}”`
      return 'New activity on this PR'
  }
}
