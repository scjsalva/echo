# Echo features

Everything Echo does, page by page. For setup, see the [README](../README.md).

- [Overview](#overview)
- [Waiting on you](#waiting-on-you)
- [Notifications](#notifications)
- [Agents](#agents)
- [Loops](#loops)
- [GitHub](#github)
- [Jira](#jira)
- [AI reviews](#ai-reviews)
- [Skills and your own instructions](#skills-and-your-own-instructions)
- [Settings](#settings)
- [Privacy and safety](#privacy-and-safety)
- [Where things live](#where-things-live)

## Overview

The home page. It refreshes on its own, instantly when Claude Code hooks are installed and otherwise every few seconds.

- **Stats** across the top. Each one links to the page behind it.

  | Group | Stat | Links to |
  |---|---|---|
  | Agents | Agents | the Agents page |
  | Agents | Busy | the Agents page |
  | Agents | Used (tokens today) | your Claude usage page |
  | Jira | Open | the Jira page |
  | Jira | Done | the Jira page's Done list |
  | GitHub | Team | the review queue, filtered to your team |
  | GitHub | Mine | your PRs |
  | GitHub | Watching | GitHub notifications in the inbox |

- **Waiting on you**: the latest items blocked on you. It's hidden when there's nothing, and "See all" opens the inbox on that tab.
- **Review queue**: the latest PRs ready for review, with a link to the full list.
- **Side panels** for agents, Jira and GitHub activity.

Clicking any item opens it in a drawer on the right. Drawers keep a Back history as you move from one item to another.

## Waiting on you

One list of everything blocked on you. Each item clears itself when its source says so, and you can also dismiss it.

| Item | Clears when |
|---|---|
| An agent waiting for permission or an answer | the agent is no longer blocked |
| A review requested from you | you submit a review |
| You or your team are mentioned on a PR | you comment on or review the PR |
| Changes requested on your PR | you push new commits or re-request review |
| You're mentioned on a Jira ticket | you comment on the ticket |
| A Jira ticket is assigned to you | you move it out of To Do |

## Notifications

### The inbox

- **Tabs:** All, Waiting on you, Jira and GitHub. The bell opens on All.
- **Filters:** show everything or unread only. Mark everything read at once.
- **Reading one:** opening a notification marks it read. GitHub ones are marked read on GitHub too.

### The bell

The bell in the top right shows the count waiting on you and the unread count. Clicking it opens the 10 latest notifications, with a link to the inbox at the bottom. Opening one marks it read, unless it's still waiting on you to act (a review request, a mention you haven't replied to, changes requested on your PR, or a Jira assignment still in To Do). The same goes for OS notifications and in-app alerts, and every open Echo page updates its count straight away.

### OS notifications and in-app alerts

- **OS notifications:** macOS, Linux (`notify-send`) or Windows. They work with no Echo page open and clear after 30 seconds.
- **In-app alerts:** shown on any open Echo page when OS notifications are off.
- **Clicking either:** it opens the item (PR, ticket or agent) in a drawer over the page you're on, without leaving it. If no Echo tab is open, a new one opens straight to the item.
- **Sound:** optional, with a Send test button in Settings.
- **Layout:** every notification, OS or in-app, is two lines: what it's about, then the message, e.g. "GitHub · web · dana approved your PR".

### What gets sent

- **Simple:** only what's waiting on you (the items above), plus the review reminder if it's on.
- **Custom:** pick from everything Echo can send:
  - An agent is waiting on you
  - For System: the review reminder, and a teammate's PR becoming ready for review
  - Review requested from you
  - You or your team are mentioned
  - Changes requested on your PR
  - New commits after your review
  - Someone approves a PR
  - Someone reviews a PR, or a review is dismissed
  - Comments
  - A PR is merged
  - A PR is closed
  - CI activity
  - Other activity on PRs you watch (including anything GitHub adds later)
  - For Jira: you're mentioned, a ticket is assigned to you, comments, and status changes
- **Unticked kinds** still appear in the inbox, but as read. They don't notify you and don't add to the unread count.
- **Kinds added later** start ticked.
- **Your own activity,** and bots' comments, never notify you.

### Review reminder

Every 15 or 30 minutes, or every 1, 2 or 4 hours (the default is 30 minutes), Echo can say how many PRs in your review queue are waiting for review, leaving out approved ones. It's only sent while there are some, and it can be turned off. Under Custom, unticking "Review reminder" turns it off too, and greys out its interval setting.

## Agents

Every live Claude Code session on your machine, read from Claude Code's own files.

- **Status:** busy, idle or waiting on you, plus model, branch, working folder, tokens today, context use, loops and subagents.
- **Filters:** all, waiting on you, with loops, background, and started by Echo.
- **The agent drawer:**
  - **Show terminal** brings the session's Terminal or iTerm2 tab to the front. It isn't available for tmux or background jobs.
  - **Rename** names the session with Claude Code's own `/rename`, so the name stays with it.
  - **Summarise** gives a short summary of where the session has got to. It uses Haiku, costs a few thousand tokens, and you can change which skill it uses.
  - **Transcript** shows the conversation.
  - **End session** quits a live session after you confirm.
- **Started by Echo:** runs Echo starts itself, for AI reviews, questions and summaries, are tagged with what they're for and the PR. They end on their own; a run that times out or errors is stopped with anything it started, so no idle agents are left behind.
- **Ended sessions:** paged, and searchable by title, folder or branch. Resume one in a new Terminal window with `claude --resume`.

## Loops

Everything running on a schedule inside your sessions: `/loop`, scheduled wake-ups and cron jobs. Each shows its session, when it last and next runs, how often, and the tokens its session has used since it started.

## GitHub

Uses the GitHub CLI (`gh`) and its login.

- **Review queue:** open, non-draft PRs by other people in the repos you watch, newest first.
  - **Filters:** everyone, requested from you, or your team; filter by repo, and search by title, number or author.
  - **Each PR shows:** its CI state and review status (Approved, Changes requested or Review required), and whether it's requested from you.
- **My PRs:** your open PRs and drafts, newest first.
- **Load more** shows 20 at a time and keeps what you've loaded when the page refreshes.
- **The PR drawer:**
  - the description, files, lines and commits changed, and reviews
  - GitHub comments, grouped into threads for comments on lines; bot comments start collapsed
  - buttons for Open on GitHub, **Review**, which opens Echo's review page, and the Jira ticket named in the PR's title. That ticket opens even if Echo doesn't sync it, e.g. a teammate's; it's loaded from Jira when you click.
- **Syncing:** every minute. Echo also records review requests, changes requested on your PRs, new commits pushed after your review, and teammates' PRs becoming ready for review.

## Jira

Uses the Atlassian CLI (`acli`) and its login. It only ever reads.

- **Your tickets,** grouped as To do, In progress, Code review, Post development and Done. Filter to assigned to you, watching, reported by you, or all, and by issue type.
- **Done:** loaded page by page.
- **Search:** your synced tickets instantly, or all of Jira by text or ticket key.
- **The ticket drawer:** status, description, custom text fields (e.g. acceptance criteria), parent and linked tickets, attachments, and comments, newest first.
- **Syncing:** every minute. Mentions, assignments, comments and status changes become notifications.

## AI reviews

Open any PR's **Review** button, or go to `/reviews/<owner>/<repo>/<number>`. You can review it yourself, with Claude, or both. Nothing reaches GitHub until you send the review.

### The page

- **Header:** the PR's title, CI state, author, size, and your review's status.
- **File tree** on the left: folders, a filter, comment counts, and lines changed. Clicking a file jumps to it, and the file you're scrolled to is highlighted.
- **Diff** on the right, GitHub style, with a + on each line to comment.
- **Earlier comments:** unresolved review threads already on the PR, by anyone, show on their lines with every reply and a link to reply on GitHub. Resolved threads are left out. Threads on code that has since changed are listed above that file's diff as "on older code". Each file's header counts its unresolved threads.
- **Description:** a button opens it in a drawer from the left, with the PR's GitHub comments.
- **Divider:** drag it to resize the panels, use the arrow keys, or double-click to reset. The width is remembered.

### Claude's review

- **Start AI review:**
  - Claude reads the PR's code from a checkout of its latest commit. It can read and search the code but can't run anything.
  - It uses your own instructions and the review skill for that repo (see below).
  - It stages comments on lines.
- **Every finding is checked:** Claude has to say which files and lines it read and mark it verified. Unverified findings, and ones not on a line in the diff, are left out and listed under "left out".
- **Severity:** High, Medium, Low or Nit.
- **"How Claude checked this"** shows each comment's evidence.
- **A verdict every run:**
  - The ▾ next to Review again shows Claude's summary of what it checked.
  - When it found nothing, the button turns green and the summary says it looks good to approve and why.
  - An empty answer counts as a failed run, not a clean review.
  - "Use as review summary" copies the verdict into Send review.
- **Leaving the page** doesn't stop a review; it runs on the server, and the page picks it back up when you return.
- **How many at once:** up to 3 AI reviews run at the same time; change it (1 to 5) in **Settings → Claude**. Any more show **Queued** and start as one finishes. A review cut off part-way, e.g. by a restart, is marked as interrupted and frees its slot, so you can start it again.

### Comments

- **Staged:** comments start staged. **Commit** the ones you want to send; only committed comments are posted.
- **Edit, Remove and Ask AI** on each comment:
  - Ask Claude things like "is this really a bug?" or "make it shorter".
  - Claude reads the code to answer, and its reply can become the comment.
- **Ask AI on a new line comment:** ask about a line before writing anything, and turn the answer into the comment.
- **Markdown:** a Write / Preview toggle, and GitHub `suggestion` blocks work.

### Sending

- **Send review** opens a dropdown, like GitHub's "Finish your review":
  - a summary (Markdown, with preview)
  - **Comment**, **Approve** or **Request changes** (the last two aren't available on your own PR)
- Your summary and choice are kept if you close and reopen the dropdown.
- Once sent, the review links to GitHub and can't be changed in Echo.
- **Merged PRs** can't be reviewed: the page says so, and the server refuses.

## Skills and your own instructions

### Skills

Each of Echo's Claude actions is driven by a skill. Echo ships its own, which live inside the app and are never installed into your `~/.claude`:

| Action | Echo's skill |
|---|---|
| AI review | `echo-review` |
| Ask Claude about a comment | `echo-review-question` |
| Session summary | `echo-summary` |

- **Using your own:** swap in one of your skills (`~/.claude/skills`) or the repo's (`.claude/skills`, read from your clone). AI review and Ask Claude can use a different skill per repo.
- **Where to change it:** **Settings → Claude** has the full list. Each button also shows its skill, with a gear to change it on the spot.
- **What stays fixed:** a skill only replaces the instructions. Echo's rules for the action still apply (read-only, verified findings, always a verdict), so the review page keeps working whatever the skill says.
- **If a skill is deleted,** the action falls back to Echo's own.

### Your own instructions

Every Claude run Echo starts includes, the same way Claude Code would load them:

- `~/.claude/CLAUDE.md` and any files it pulls in with `@path`
- for reviews and questions, the repo's `CLAUDE.md` and `CLAUDE.local.md`

Repo instructions come from your clone, or the default branch of Echo's copy, and never from the PR being reviewed. **Settings → Claude** lists every file that's sent and its size.

**Extra context:** in the same place you can add your own files or skills, for every run or for one repo:
- A path starting with `~` or `/` is used as it is. For a repo, any other path is inside your clone, e.g. `docs/architecture.md`.
- A skill added this way is reference only; it doesn't change the skill an action uses.
- A file or skill that has moved or been deleted is skipped and marked missing, instead of failing the run.

## Settings

Settings is split into sections, listed on the left: Connections, GitHub, Claude, Notifications and General. The address follows the section, e.g. `/settings#claude`, so it can be linked to. A dot next to Connections means something isn't connected.

- **Connections:** GitHub, Jira and Claude Code hooks. Echo never asks for tokens: logging in opens Terminal with the CLI's own login command.
- **GitHub:**
  - the repos the review queue watches
  - your team (with suggestions from your organisation)
  - **Code for AI reviews:** point each repo at a clone you already have, or Echo keeps its own copy, downloaded on the first review. Once you use your own clone, you can remove Echo's copy.
- **Claude:** how many AI reviews run at once, the skills for each action and repo, and what Echo's Claude runs can see, including extra context.
- **Notifications:**
  - Simple or Custom (with the checklist)
  - the review reminder
  - OS notifications on or off
  - sound, with Send test
- **General:** your time zone (automatic or chosen), and appearance (system, light or dark).

## Privacy and safety

- **Local:** Echo runs on your machine only. Its data is in a local SQLite database.
- **GitHub and Jira:**
  - Echo only reads. The only exceptions are marking a GitHub notification read and sending a review you submitted.
  - The commands Echo may run are on a fixed allowlist.
- **Claude runs Echo starts:**
  - they're restricted to reading files, can't run commands, and ignore the reviewed repo's own Claude settings and hooks
  - they're tracked and ended when they finish or time out
- **Your clones:** when a review reads from your clone, Echo checks the PR out in a separate folder. Your branch and working files are never touched, and no branches or tags are added.

## Where things live

| What | Where |
|---|---|
| Echo's database | `storage/` in the project |
| Notifier app, notifier log, copies of repos | `~/Library/Application Support/Echo` (macOS) or `~/.local/share/echo` |
| Claude Code sessions and transcripts (read only) | `~/.claude` |
| Hooks (only if you install them) | `~/.claude/settings.json`, backed up first |
| The background service (`bin/service`) | a launchd agent at http://localhost:4747 |
