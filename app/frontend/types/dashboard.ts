export type AgentStatus = 'busy' | 'idle' | 'blocked' | 'running'

/** A Monitor watch, a self-paced /loop (ScheduleWakeup) or a cron job running inside a session. */
export interface AgentLoop {
  id: string
  kind: 'monitor' | 'wakeup' | 'cron'
  description: string
  startedAt: string
  events: number
  lastEventAt: string | null
  nextRunAt?: string | null
  expiresAt?: string | null
  every?: number
  cron?: string
  /** Tokens the host session has used since the loop started, to the hour. */
  sessionTokensSinceStart?: number | null
}

export interface Subagent {
  type: string
  name?: string
  status: 'running' | 'done'
  result: string
  active: string
}

export interface Agent {
  id: string
  /** The name given with /rename, or Claude Code's handle when there isn't one. */
  name: string
  /** Claude Code's own short name, e.g. "projects-f4". */
  handle?: string
  renamed?: boolean
  cwd: string
  branch?: string | null
  kind: 'yours' | 'managed' | 'background'
  /** Set when Echo started this session itself, e.g. for an AI review. */
  task?: { purpose: 'ai_review' | 'review_question' | 'summary'; label: string; ref: string | null } | null
  /** Why Show terminal can't work for this agent (no terminal window, tmux, a background job), if it can't. */
  terminalUnavailable?: string | null
  status: AgentStatus
  model: string
  started: string
  active: string
  tokensToday: number
  tokensTotal: number
  contextPercent: number | null
  turns: number | null
  hourlyTokens: number[]
  title?: string | null
  summary?: string | null
  lastPrompt: string | null
  lastReply: string | null
  needs?: string | null
  loops: AgentLoop[]
  subagents: Subagent[]
  jobs: { state: string; detail: string }[]
}

export type CiState = 'passing' | 'failing' | 'running'
export type ReviewState = 'approved' | 'changes_requested' | 'review_required' | 'draft'

export interface PullRequest {
  key: string
  repo: string
  /** owner/name */
  fullName?: string
  number: number
  url: string
  jiraKey?: string
  title: string
  summary: string
  /** The full description, in Markdown. */
  description?: string | null
  author: string
  mine: boolean
  draft: boolean
  ci: CiState
  reviewState: ReviewState
  approvals?: number
  approvalsRequired?: number
  requestedFromMe: boolean
  opened: string
  updated: string
  additions: number
  deletions: number
  changedFiles: number
  commits: number
  reviews: { login: string; state: string }[]
}

export type GithubReason =
  | 'review_requested' | 'comment' | 'mention' | 'team_mention' | 'follow_up' | 'changes_requested'
  | 'ci_activity' | 'author' | 'assign' | 'state_change' | 'subscribed' | 'manual'
  | 'approved' | 'reviewed' | 'review_dismissed' | 'merged' | 'closed' | 'ready_for_review' | 'changes_requested_other'

export interface GithubNotification {
  id: string
  reason: GithubReason
  prKey: string
  title?: string | null
  /** Missing when the activity wasn't a comment, e.g. a status change. */
  actor: string | null
  body?: string | null
  at: string
  unread: boolean
  resolution?: string | null
  url?: string
  /** Whether the PR is yours, for "approved your PR" versus "approved the PR". */
  mine?: boolean
}

export type JiraCategory = 'todo' | 'in_progress' | 'code_review' | 'post_development' | 'done'

export interface JiraTicket {
  key: string
  url: string
  title: string
  type: string
  status: string
  category: JiraCategory
  priority: string
  assignee: string
  reporter: string
  sprint: string | null
  pr?: string
  description: string | null
  /** Unknown for older tickets loaded straight from Jira's search. */
  updated: string | null
  assignedToMe: boolean
  watching?: boolean
  reportedByMe?: boolean
}

export type JiraKind = 'mention' | 'comment' | 'transition' | 'assigned'

export interface JiraRelatedTicket {
  key: string
  url: string
  title: string | null
  status: string | null
  relation?: string
}

/** Everything readable on a ticket, loaded when its panel opens. */
export interface JiraTicketDetail {
  key: string
  url: string
  description: string | null
  environment: string | null
  creator: string | null
  created: string | null
  updated: string | null
  due: string | null
  resolution: string | null
  resolved: string | null
  labels: string[]
  components: string[]
  fixVersions: string[]
  affectsVersions: string[]
  timeTracking: { originalEstimate?: string; remainingEstimate?: string; timeSpent?: string } | null
  parent: JiraRelatedTicket | null
  subtasks: JiraRelatedTicket[]
  links: JiraRelatedTicket[]
  attachments: { name: string; size: number; type: string; author: string | null; created: string }[]
  moreDetails: string[]
  comments: { id: string; author: string | null; bot: boolean; created: string; text: string | null }[]
}

export interface JiraNotification {
  id: string
  kind: JiraKind
  key: string
  url?: string
  /** Missing for status moves and assignments, which acli doesn't attribute. */
  actor: string | null
  body?: string | null
  at: string
  unread: boolean
  resolution?: string | null
}

export interface WaitingItem {
  key: string
  source: 'agent' | 'github' | 'jira'
  kind: string
  label: string
  title: string
  actor: string | null
  detail: string | null
  at: string
  clears: string
  status: 'open' | 'resolved' | 'dismissed'
  resolution: string | null
  ref: { agentId?: string; prKey?: string; ticketKey?: string; notificationId?: string }
}

export interface Connection {
  key: 'github' | 'jira' | 'claude_hooks' | 'claude_integration'
  name: string
  connected: boolean
  optional?: boolean
  /** Echo can open Terminal to log this connection in. */
  setup?: boolean
  /** Set up in one click, without a login (Claude Code hooks). */
  instant?: boolean
  /** False when logging out would also log you out elsewhere (gh is shared with your terminal). */
  logout?: boolean
  detail: string | null
}

export interface ShellProps {
  waitingCount: number
  unreadCount: number
  missingConnections: string[]
  /** Hooks are installed, so pages can refresh the moment something happens. */
  live?: boolean
  updatedAt: string
}

export interface Stats {
  agents: { agents: number; busy: number; tokensUsed: number }
  github: { team: number; mine: number; watching: number }
  jira: { open: number; done: number }
}

export interface EndedSession {
  id: string
  title: string
  cwd: string
  branch: string | null
  ended: string
  tokensTotal: number
  turns: number
  lastReply: string
  resumeCommand: string
  cursor: string
}

export interface TranscriptMessage {
  role: 'you' | 'claude' | 'tool'
  text: string
  at: string | null
}

export interface AgentSummary {
  text: string
  model: string
  generatedAt: string
}

export interface NotificationSettings {
  desktop: boolean
  /** Where to allow Echo's notifications on this system, e.g. "System Settings → Notifications → Echo". */
  settingsHint: string
  /** Whether this computer can show them (e.g. notify-send is installed on Linux). */
  available: boolean
  scope: 'waiting' | 'custom'
  /** Every kind of notification Echo sends; the waiting ones are what "Waiting on you" covers. */
  types: { id: string; group: string; label: string; waiting?: boolean }[]
  /** The kinds Custom sends. */
  enabledTypes: string[]
  /** How often to say how many PRs wait for review, in minutes; 0 is off. */
  reminderMinutes: number
  reminderOptions: number[]
  sound: string
  sounds: string[]
}

export interface TimeZoneSettings {
  preference: string
  detected: string
  current: string
  options: { value: string; label: string }[]
}

export interface GithubPageProps extends PageData {
  connected: boolean
  syncedAt: string | null
  pullRequests: PullRequest[]
  reviewQueue: PullRequest[]
  githubNotifications: GithubNotification[]
  team: string[]
  repos: string[]
}

export interface GithubPreferences {
  repos: string[]
  reposChosen: boolean
  team: string[]
  knownRepos: string[]
  knownPeople: { login: string; name: string | null }[]
  /** Where AI reviews read each repo's code from. */
  localRepos: { repo: string; path: string | null; suggestions: string[]; echoCopyBytes: number | null }[]
}

export interface JiraPageProps extends PageData {
  connected: boolean
  syncedAt: string | null
  jiraTickets: JiraTicket[]
  jiraNotifications: JiraNotification[]
}

/** What every page gets: the shell plus whichever collections it shows. */
export interface PageData {
  shell: ShellProps
  agents: Agent[]
  pullRequests?: PullRequest[]
  githubNotifications?: GithubNotification[]
  jiraTickets?: JiraTicket[]
  jiraNotifications?: JiraNotification[]
  waiting?: { items: WaitingItem[]; total: number }
}

export interface OverviewProps {
  shell: ShellProps
  stats: Stats
  waiting: { items: WaitingItem[]; total: number }
  reviewQueue: { items: PullRequest[]; total: number }
  agents: Agent[]
  pullRequests: PullRequest[]
  githubNotifications: GithubNotification[]
  jiraTickets: JiraTicket[]
  jiraNotifications: JiraNotification[]
  connections: Connection[]
}

export interface DiffLine {
  kind: 'context' | 'add' | 'del'
  old: number | null
  new: number | null
  text: string
}

export interface DiffFile {
  path: string
  previousPath: string | null
  status: string
  additions: number
  deletions: number
  hunks: { header: string; context: string; lines: DiffLine[] }[]
  tooLarge: boolean
}

export interface ReviewComment {
  id: number
  path: string
  line: number
  side: 'LEFT' | 'RIGHT'
  startLine: number | null
  body: string
  state: 'staged' | 'committed' | 'removed' | 'sent'
  author: 'ai' | 'you'
  severity: 'high' | 'medium' | 'low' | 'nit' | null
  evidence: string | null
  notes: { role: 'you' | 'claude' | 'error'; text: string }[]
  asking: boolean
}

export interface ReviewDraft {
  id: number
  prKey: string
  headSha: string | null
  status: 'draft' | 'sent'
  aiStatus: 'idle' | 'queued' | 'running' | 'done' | 'failed'
  /** What the last AI review did with each finding. */
  aiReport?: { summary: string; added: number; leftOut: { path: string; line: number; body: string; reason: string }[] } | null
  aiError: string | null
  sentAt: string | null
  githubUrl: string | null
  comments: ReviewComment[]
}

export interface ReviewPageProps {
  shell: ShellProps
  agents: Agent[]
  error?: string
  pullRequest?: PullRequest
  headSha?: string
  /** When the PR was merged; reviewing is closed from then on. */
  mergedAt?: string | null
  files?: DiffFile[]
  review?: ReviewDraft
}

export interface PullRequestComment {
  id: string
  kind: 'comment' | 'review' | 'line'
  author: string | null
  bot: boolean
  body: string
  at: string
  url: string | null
  state?: string
  path?: string
  line?: number | null
  /** The id of the line comment this is a reply to, or absent for a thread's root. */
  replyTo?: string | null
}

export interface SkillOption {
  id: string
  name: string
  description: string
  /** echo: shipped with Echo · user: ~/.claude/skills · repo: the repo's .claude/skills */
  source: 'echo' | 'user' | 'repo'
}

export interface SkillChoice {
  repo: string
  /** Set when this repo uses its own skill instead of the action's. */
  override: string | null
  current: SkillOption
  options: SkillOption[]
}

export interface SkillAction {
  action: 'ai_review' | 'review_question' | 'summary'
  label: string
  perRepo: boolean
  current: SkillOption
  options: SkillOption[]
  repos: SkillChoice[]
}

export interface ContextExtra {
  kind: 'file' | 'skill'
  value: string
  repo: string | null
  found?: boolean
}

export interface ContextFile {
  label: string
  path: string
  chars: number
}

export interface ClaudeSettings {
  /** How many AI reviews run at once; more wait their turn. */
  reviewLimit: number
  reviewLimitOptions: number[]
  skills: SkillAction[]
  context: {
    global: ContextFile[]
    repos: { repo: string; files: ContextFile[] }[]
    /** Files and skills you added; repo null means every run. */
    extras: ContextExtra[]
  }
}

/** An earlier, still unresolved review thread on a PR, from any author. */
export interface ReviewThread {
  id: string
  path: string
  side: 'LEFT' | 'RIGHT'
  line: number | null
  startLine: number | null
  /** The code it was left on has changed, so it has no line in the current diff. */
  outdated: boolean
  originalLine: number | null
  comments: { id: string; author: string | null; body: string; at: string; url: string | null }[]
}
