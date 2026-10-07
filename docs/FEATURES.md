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
- [Echo in Claude Code](#echo-in-claude-code)
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
  | Jira | Unassigned (open on your board, nobody's, leaving out the Backlog) | the Jira page, filtered to Unassigned |
  | Jira | To Do (yours and not started, your Backlog tickets included) | the Jira page, Assigned to me on |
  | Jira | Done (yours, finished in the last 14 days) | the Jira page, Assigned to me on |
  | GitHub | Team | Team, with Ready for review selected |
  | GitHub | Mine | your PRs |
  | GitHub | Watching | GitHub notifications in the inbox |

- **Waiting on you**: the latest items blocked on you. It's hidden when there's nothing, and "See all" opens the inbox on that tab.
- **Review queue**: the latest PRs ready for review, with a link to the full list.
- **Side panels** for agents, Jira and GitHub activity. Jira's lists your open tickets, To do included.

Clicking any item opens it in a drawer on the right. Drawers keep a Back history as you move from one item to another.

Every page's tabs, filters and search live in the address bar (e.g. `/github?tab=team&status=ready`, `/inbox?tab=waiting`), so a reload, a bookmark or a shared link shows the same view. Defaults are left out, so a plain link opens the page as normal. Links that open one item (e.g. `?ticket=` or `?pr=`) are tidied away once it's open; the filters stay.

## Waiting on you

One list of everything blocked on you. Each item clears itself when its source says so, and you can also dismiss it.

| Item | Clears when |
|---|---|
| An agent waiting for permission or an answer | the agent is no longer blocked |
| A review requested from you | you submit a review |
| Asked to review again (the author re-requested your review) | you submit a review |
| You or your team are mentioned on a PR | you comment on or review the PR |
| Changes requested on your PR | you push new commits or re-request review |
| You're mentioned on a Jira ticket | you comment on the ticket |
| A Jira ticket is assigned to you | you move it out of To Do |

Clicking an item opens its PR, ticket or agent straight away, with a **Dismiss** button right under its notification message. Opening a notification that's waiting on you from the bell, the inbox or an OS notification shows it too. Only something Echo can't open (e.g. a ticket it doesn't sync) opens a summary of the item instead.

## Notifications

### The inbox

- **Tabs:** All, Waiting on you, Jira and GitHub. The bell opens on All.
- **Filters:** show everything or unread only. Mark everything read at once.
- **Reading one:** opening a notification marks it read. GitHub ones are marked read on GitHub too.

### The bell

The bell in the top right shows the count waiting on you and the unread count; the unread count also leads the tab's title, e.g. "(3) GitHub · Echo". Hovering it opens the 10 latest notifications (every unread one shows too, however old, so the count always matches the dots), what's waiting on you first under Waiting on you (only when there's something, and not repeated below), then unread ones under Unread and the rest under Earlier, so one that reached Echo late isn't buried among those you've read, with a link to the inbox at the bottom; clicking it goes to the inbox. The dots on what's new stay for as long as it's open; it marks what it shows as read when you move away (passing over the bell, open under half a second, marks nothing), except what's still waiting on you to act (a review request, a mention you haven't replied to, changes requested on your PR, or a Jira assignment still in To Do). Their dots then fade out, so you see what was new first. Opening a notification (from the bell, an OS notification or an in-app alert) marks it read, even one still waiting on you: that stays in Waiting on you until it's done or dismissed. Dismissing a waiting item marks its notification read too. Every open Echo page updates its count straight away.

### Open on your phone

Hovering the phone button in the top right shows a QR code for the page you're on, at the Mac's local network address. Scan it with a phone on the same Wi-Fi to open that page there. The button only shows on the Mac itself (Echo opened at localhost), not on a phone or other device, and only when the Mac has a local network address, and the page only loads if Echo is listening on the network rather than just on this Mac (`bin/rails server -b 0.0.0.0`, with `VITE_RUBY_SKIP_PROXY=false` so the phone gets its scripts through Rails).

### OS notifications and in-app alerts

- **OS notifications:** macOS, Linux (`notify-send`) or Windows. They work with no Echo page open and clear after 30 seconds.
- **In-app alerts:** shown on any open Echo page when OS notifications are off, each with Echo's logo in its source's colour: orange for agents, purple for GitHub, blue for Jira.
- **Colour-coded icons (Mac, off by default):** OS notifications show Echo's icon in the same colours. macOS ties a notification's icon to the app that sends it, so this uses three small helper apps, one per source; macOS asks you to allow each once. Off, every notification comes from Echo, with one icon and one permission.
- **Clicking either:** it opens the item (PR, ticket or agent) in a drawer over the page you're on, without leaving it. If no Echo tab is open, a new one opens straight to the item.
- **Sound:** optional, with a Send test button in Settings.
- **Layout:** every notification, OS or in-app, is two lines: what it's about, then the message, e.g. "GitHub · web · dana approved your PR".

### What gets sent

- **Simple:** only what's waiting on you (the items above), plus the review reminder if it's on, and when an AI review you started finishes or fails.
- **Custom:** pick from everything Echo can send:
  - An agent is waiting on you
  - An AI review of a PR finishes (or fails); clicking it opens the review
  - For System: the review reminder, and a teammate's PR becoming ready for review
  - Review requested from you
  - You or your team are mentioned
  - Changes requested on your PR
  - New commits after your review
  - Asked to review again: the author re-requested your review after you'd reviewed (a waiting item, like a review request)
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
- **Replies on review threads** notify you only in threads you started or have commented in, or when they mention you.

### Looks ready for another look

Off until you turn it on in Settings → Notifications. A guess, for authors who don't re-request your review: on a PR you reviewed, the author (a person, not a bot) has pushed new commits since your review, answered or resolved every thread you started, CI passes, and they've been quiet for 30 minutes. Sent once per round of review, whatever the scope; a re-request says it better, so it's skipped when one is open.

### Working hours

Turn on **Working hours** in Settings → Notifications and choose your days and hours. Outside them, Echo sends nothing (no OS notifications, in-app alerts or review reminders). Anything that came in meanwhile arrives when your hours start: the first 3, then "…and N more".

- **Past midnight:** a shift can run past midnight, e.g. 4pm to 1am. It counts as the day it starts, so 1am Saturday is still Friday's shift.
- **Time zone:** times are in Echo's time zone, set in Settings → General (automatic by default), so 8am to 5pm means 8am to 5pm wherever you are.
- **The inbox:** it still fills up as usual; only the notifying waits.

### Review reminder

Every 15 or 30 minutes, or every 1, 2 or 4 hours (the default is 30 minutes), Echo can say how many PRs in your review queue are waiting for review, leaving out approved ones. It's only sent while there are some, and it can be turned off. Under Custom, unticking "Review reminder" turns it off too, and greys out its interval setting.

## Agents

Every live Claude Code session on your machine, read from Claude Code's own files.

- **Status:** busy, idle or waiting on you, plus model, branch, working folder, tokens today, context use, loops and subagents.
- **Filters:** all, waiting on you, with loops, background, and started by Echo.
- **The agent drawer:**
  - **Show terminal** brings the session's tab to the front: Terminal or iTerm2 on macOS, or its tmux pane on macOS or Linux. Other terminals (and Windows) give Echo no way in, so it isn't offered there, nor for background jobs.
  - **Rename** names the session with Claude Code's own `/rename`, so the name stays with it. Echo types the command into the session, so it only renames an idle session (typing into a busy one could land in, and send, what you're writing there); clear anything half-typed there first.
  - **Summarise** gives a short summary of where the session has got to. It uses Haiku, costs a few thousand tokens, and you can change which skill it uses.
  - **Transcript** shows the conversation.
  - **End session** quits a live session after you confirm.
- **Started by Echo:** runs Echo starts itself, for AI reviews, questions and summaries, are tagged with what they're for and the PR. They end on their own; a run that times out or errors is stopped with anything it started, so no idle agents are left behind.
- **Ended sessions:** paged, and searchable by title, folder or branch. Resume one in a new terminal window with `claude --resume` (Terminal on macOS, your desktop's terminal on Linux, Windows Terminal or a command prompt on Windows).

## Loops

Everything running on a schedule inside your sessions: `/loop`, scheduled wake-ups and cron jobs. Each shows its session, when it last and next runs, how often, and the tokens its session has used since it started.

## GitHub

Uses the GitHub CLI (`gh`) and its login.

- **Tabs,** newest first:
  - **All:** every open PR in the repos you watch, drafts and yours included.
  - **Team:** the All PRs by your team (people and teams set in Settings → GitHub), not yours.
  - **My PRs:** your open PRs and drafts, in any repo.
- **Filters:** a Filters button (hover or tap) with pill groups for **Status** (Ready for review, Draft), **Reviews** (Review required, Approved, Changes requested, Requested from me), **Author** and **Repo**. Choices in one group match any of them; groups combine. The button counts how many are on. Search by title, number or author too.
- **Each PR shows:** its CI state and review status (Approved, Changes requested or Review required), and whether it's requested from you.
- **The review queue** on the Overview is your team's ready-for-review PRs in the repos you watch. Its link, and the Team stat, open Team with Ready for review selected.
- **Load more** shows 20 at a time and keeps what you've loaded when the page refreshes.
- **The PR drawer:**
  - the description, files, lines and commits changed, and reviews
  - GitHub comments, grouped into threads for comments on lines; bot comments start collapsed
  - buttons for Open on GitHub, **Review**, which opens Echo's review page, and the Jira ticket named in the PR's title. That ticket opens even if Echo doesn't sync it, e.g. a teammate's; it's loaded from Jira when you click.
- **Syncing:** every minute. Echo also records review requests, changes requested on your PRs, new commits pushed after your review, and teammates' PRs becoming ready for review.

## Jira

Uses the Atlassian CLI (`acli`) and its login. It only reads, except for one change you make yourself: assigning a ticket to you, or taking you off it.

- **Your board:** choose the one board you follow in Settings → Jira (search by name); to switch, remove it and choose another. Its tickets come from its saved filter: what's open, plus anything done in the last 14 days. The Atlassian CLI can't read a board's columns, so its statuses are the ones its tickets use, in Jira's category order until you reorder them; hide the ones you don't want. The Backlog starts hidden, as Jira keeps it off a board, on its own page.
- **The board,** like Jira's: a **To Do** column gathering every to-do status (e.g. Ready to Start) plus your own Backlog tickets, then a column per shown status in the board's order. Each card shows the title, its sprint, type and key, priority and the assignee's avatar. A child sits right under its parent when both are in the same column, and a subtask has a line down its left, wherever its parent is. Searches can't return a ticket's parent, so the sync finds which tickets have one and looks each up, up to 40 a sync, remembering it for 6 hours. The board fills the screen below it and scrolls itself, up and down and sideways, with each column's name staying in view.
- **Filters:** **Assigned to me** as a quick filter, and a Filters button with **Status** (hidden statuses too), **Ticket type**, **Assignee** (including Unassigned) and, on a scrum board, **Sprint**. Assigned to me and your name under Assignee are the same choice. A scrum board opens on its active sprint. The button counts what's on. The filters and search live in the address bar (e.g. `/jira?assignee=me&type=Bug`), so a reload, a bookmark or a shared link shows the same board; a link from the Overview's stats sets just its own filter, so the board matches what it counted.
- **Search:** the board's tickets instantly, or all of Jira by text or ticket key.
- **The ticket drawer:** status, description, custom text fields (e.g. acceptance criteria), parent and linked tickets, attachments, and comments, newest first.
- **Assign to me / Unassign:** in the ticket drawer, an unassigned ticket can be assigned to you, and one of yours unassigned. Echo then reads back who has it, so the board updates at once. Other people's tickets can't be unassigned from Echo.
- **Ask Claude:** from the ticket drawer, opens Claude Code in a new Terminal tab (a new window if there's no Terminal window, or no Accessibility access for the ⌘T) to talk the ticket through before you pick it up. It starts in the folder holding your local repos (set in Settings → GitHub) and works out with you which of them the change belongs in, since a ticket can span two or turn out to be a bug in a package. It starts from a brief Echo gathers: the whole ticket and its comments, the parent, subtasks and linked tickets read in full, every link in them sorted by kind (GitHub, recordings and bug captures, designs and docs, tickets), the attachments (listed only: the Atlassian CLI can't download them), and PRs in your repos that mention the ticket. The **Ask Claude about a ticket** skill (Echo's echo-ticket, or yours, in Settings → Claude → Skills) then tells Claude to dig further with whatever tools the session has, e.g. `gh` for PRs and MCP servers for recordings, designs or the tracker's attachments, before evaluating it with you. It stays read-only until you ask it to build.
- **Resume session:** Echo records each session it opens for a ticket, so the drawer can bring the latest one back: **Go to session** brings its Terminal tab forward while it's running, and **Resume session** picks it up again (`claude --resume`) in a new tab once it has ended. Only sessions Echo opened are offered.
- **Find me work** (`/jira/work`, from the button by the board's filters): the unassigned tickets in your board's To Do column (not the Backlog or a hidden status), each with what it's about, what you'd do, a rough size (a few hours, a day or two, bigger), and whether something needs answering first. The **Top picks** are the best five: summarised, ready to start, then by priority, due date and size; everything else is in a table below, ten at a time with Load more. Choose how to pick (kept in the address bar, e.g. `?pick=quick`): **Best overall**, **Quick wins** (a few hours and ready), **Urgent** (overdue, due within a week, or high priority), **Bugs**, **Needs clarifying** (worth asking about to unblock), and from tags Claude adds with its summary, **Data corrections**, **Frontend**, **Backend**, **Investigations** and **Customer-reported**. Only the tags need Claude, and they come in the same call as the summary. Clicking one opens its ticket drawer. **Find me work** has Claude (Haiku) summarise the ones that need it, eight to a call, from the ticket's trimmed text with no tools; **Refresh** on a ticket reads it from Jira again. To keep it cheap, a summary is kept for 14 days and only redone when the ticket's words change (or Echo changes what it asks Claude for); it goes sooner once someone else has the ticket and it's moved on, or it leaves the board. Claude only runs when you press a button; the ranking itself uses none.
- **Syncing:** every minute: your own tickets (assigned, watching or reported), which become notifications for mentions, assignments, comments and status changes, and each board's tickets.

## AI reviews

Open any PR's **Review** button, or go to `/reviews/<owner>/<repo>/<number>`. You can review it yourself, with Claude, or both. Nothing reaches GitHub until you send the review.

### The page

- **Header:** the PR's title, CI state, author, size, and your review's status.
- **File tree** on the left: folders, a filter, comment counts, and lines changed. Clicking a file jumps to it, and the file you're scrolled to is highlighted.
- **Diff** on the right, GitHub style, with a + on each line to comment.
- **Earlier comments:** unresolved review threads already on the PR, by anyone, show on their lines with every reply and a link to reply on GitHub. Resolved threads are left out. Threads on code that has since changed are listed above that file's diff as "on older code". Each file's header counts its unresolved threads. Threads start folded to one line (who started it and how many comments); click one to read it. The **Earlier comments** switch above the diff hides or shows them all, and is remembered.
- **Description:** a button opens it in a drawer from the left, with the PR's GitHub comments.
- **Divider:** drag it to resize the panels, use the arrow keys, or double-click to reset. The width is remembered.

### Claude's review

- **Start AI review** (and **Review again**) opens a panel where you can direct Claude first, e.g. "focus on app/models/order.rb", "check it meets the ticket's criteria" or "ignore the test changes". Claude treats it as the priority for that review; its rules still apply. Your direction is kept, so Review again starts with it. Leave it empty for a normal review.
- **What the review does:**
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

### Rewrite in your words

Off until you choose one of your own skills for it in Settings → Claude → Skills (e.g. one that makes a finding read as if you wrote it). Then a **Rewrite** button shows on every comment and reply that has text (Claude's findings and your own), in the box where you write a comment or reply, and in the Send review dialog for the summary. On a saved comment, the rewrite shows under it like an Ask AI answer, ready to **Use as comment**; in the box you're writing in, and the summary, it's rewritten in place, with **Undo**. Claude gets your skill and the text only, no tools, and the button has no skill picker of its own.

### Earlier threads

- Earlier reviews' threads, by anyone, sit on their lines (or above the diff when the code has since changed), resolved ones marked as such.
- **Reply:** write a reply, or ask Claude about the thread first. Claude reads the whole thread and the code, and its answer can become the reply. A reply works like a comment: **Commit** it to send with your review, or **Send now** to post it on GitHub straight away.
- **Resolve / Unresolve** a thread on GitHub in one click.
- Replies, resolving and unresolving are the only changes Echo makes to existing threads, each one a fixed GitHub mutation.

### Sending

- **Send review** opens a dropdown, like GitHub's "Finish your review":
  - a summary (Markdown, with preview)
  - **Comment**, **Approve** or **Request changes** (the last two aren't available on your own PR)
- Your summary and choice are kept if you close and reopen the dropdown.
- Committed replies go out with the review, each to its thread. Replies alone need no summary.
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

In a review they guide how Claude reviews the code, but the PR's author is never held to them: your own conventions for writing PRs (descriptions, commit messages, attribution lines) aren't theirs, so Claude doesn't comment on those.

**Extra context:** in the same place you can add your own files or skills, for every run or for one repo:
- A path starting with `~` or `/` is used as it is. For a repo, any other path is inside your clone, e.g. `docs/architecture.md`.
- A skill added this way is reference only; it doesn't change the skill an action uses.
- A file or skill that has moved or been deleted is skipped and marked missing, instead of failing the run.

## Echo in Claude Code

Install it from **Settings → Connections → Echo in Claude Code**. It adds:

- **The status line:** your counts at the bottom of every Claude Code session, e.g. `Echo: 2 waiting · 5 unread · 17 to review`, or `Echo: all clear`. If you already had a status line, it keeps running, with Echo's counts after it. When Echo isn't running, the counts simply don't show.
- **`/echo`:** a summary of what's waiting on you, unread notifications and the review queue. Or ask for one part:

  | Command | What it does |
  |---|---|
  | `/echo waiting` | what's waiting on you |
  | `/echo inbox` | unread notifications |
  | `/echo prs` | the review queue |
  | `/echo mine` | your own open PRs |
  | `/echo pr #27014` | one PR in full: status, CI, reviews, description and its unresolved threads |
  | `/echo review #27014` | an AI review, same as `/echo-review` |
  | `/echo agents` | live agents |
  | `/echo jira APP-123` | a Jira ticket |
  | `/echo read <id>` | mark a notification read (`read all` for everything) |
  | `/echo dismiss <key>` | dismiss a waiting item |
  | `/echo focus <agent>` | bring an agent's terminal forward |

  Claude can use it without being asked too, e.g. "anything need me?".
- **PRs can be given** as `#27014` or just `27014` (Echo works out the repo, and asks if two of your repos share that number), `web#27014`, `owner/repo#123`, or a GitHub link.
- **`/echo-review <PR>`:** starts an AI review in Echo, waits for it, and shows the verdict and the comments it staged. It never posts to GitHub: you send reviews from Echo's review page.

The skills live in `~/.claude/skills/echo` and `~/.claude/skills/echo-review`. Echo keeps installed copies up to date when it starts, won't overwrite a skill of yours with the same name, and **Remove** takes everything back out and restores your previous status line. They talk to Echo through local-only plain-text endpoints under `/api/cli`, so they're cheap on tokens.

## Settings

Settings is split into sections, listed on the left: Connections, GitHub, Claude, Notifications and General. The address follows the section, e.g. `/settings#claude`, so it can be linked to. A dot next to Connections means something isn't connected.

Changes wait for **Save**, section by section. Once something in a section changes, **Save** and **Cancel** appear at its bottom and a dot marks the section in the list. Both apply to that section only; Cancel puts its settings back to how they were, including the theme, which previews as you pick it. Moving to another section, or leaving Settings, with unsaved changes asks first. Actions still happen straight away: logging in and out, installing or removing, Send test, and removing Echo's copy of a repo.

- **Connections:** GitHub, Jira, Claude Code hooks, and Echo in Claude Code.
- **Health** (under Connections): how each background sync is doing (GitHub, Jira and the notification check). It shows when each last succeeded, any failures in a row with the last error, and a **Sync now** button, on top of the automatic runs. Failed syncs retry on their own every minute.
  - **Scheduler:** Health also shows the background scheduler that starts the syncs. If it stops for 3 minutes, Echo runs the syncs itself until it picks up again, and it clears out jobs left behind by a worker that died.
  - **On waking:** Echo notices the computer slept (on macOS, Linux or Windows), ends any sync that was stuck mid-run since before the sleep, and syncs straight away.
  - **After a long pause:** if no sync has started for 30 minutes (the computer slept, or the queue got stuck), Echo restarts itself and everything starts fresh; there's nothing to do. Pages cover themselves while Echo catches up after 10 minutes or more asleep: "Echo is restarting" while it's down, then each connection's sync as it runs again, closing once they're all up to date. **Continue anyway** appears if it takes a while.
  - **Logins:** a login check that fails just after waking (no network yet) doesn't count as logged out; the last good status stands for up to 10 minutes.
  - **Stuck runs:** each sync runs one at a time using a lock the system releases if its process dies, so a crash or the computer sleeping can't leave the next runs waiting. A sync that's being queued but not starting shows as **Not starting**.
  - **The status light** at the top right is green when every connected sync is up to date, amber when one is behind, and red when one is failing or not starting. Hover it for a summary, each sync's status and when it last synced, and when the page last updated. Click it to open Health.
  - **After sending a review:** Echo syncs GitHub straight away, so an approval shows at once. Echo never asks for tokens: logging in opens a terminal with the CLI's own login command.
- **GitHub:**
  - the repos the review queue watches
  - your team: people, and GitHub teams written `org/team` (suggested from your organisations), where a team counts everyone in it; members are looked up on GitHub and refreshed every 10 minutes
  - **Code for AI reviews:** point each repo at a clone you already have, or Echo keeps its own copy, downloaded on the first review. Once you use your own clone, you can remove Echo's copy.
- **Claude:** how many AI reviews run at once, the skills for each action and repo, and what Echo's Claude runs can see, including extra context.
- **Notifications:**
  - Simple or Custom (with the checklist)
  - the review reminder
  - OS notifications on or off
  - sound, with Send test
- **General:** your time zone (automatic or chosen), keeping the computer awake, and appearance (system, light or dark).
  - **Keep the computer awake:** off by default. *While agents are working* stops idle sleep while a Claude Code session or one of Echo's AI reviews or questions is busy, and for 2 minutes after; *During working hours* stops it for all of your working hours (or all the time, if working hours are off), even with nothing running, which drains a battery noticeably faster. The screen still turns off and locks on its usual timer, and closing a laptop's lid still sleeps it. A coffee cup in the header shows while it's holding, with why. It uses `caffeinate` on macOS, `systemd-inhibit` on Linux and `SetThreadExecutionState` on Windows, through a helper that ends if Echo does. (Claude Code itself already stops idle sleep on macOS while a session works.)

## Privacy and safety

- **Local:** Echo runs on your machine only. Its data is in a local SQLite database.
- **Logs:** they never contain what Claude Code hooks send (your prompts, what agents ran and saw, Claude's replies); those show as `[FILTERED]`. Logs roll over at 10MB, keeping one old file.
- **GitHub and Jira:**
  - Echo only reads. The only exceptions are marking a GitHub notification read and sending a review you submitted.
  - The commands Echo may run are on a fixed allowlist.
- **Claude runs Echo starts:**
  - they're restricted to reading files, can't run commands, and ignore the reviewed repo's own Claude settings and hooks
  - they're tracked and ended when they finish or time out
- **Your clones:** when a review reads from your clone, Echo checks the PR out in a separate folder. Your branch and working files are never touched, and no branches or tags are added.

## What Echo keeps, and for how long

An hourly clean-up keeps Echo's data small:

| What | Kept for |
|---|---|
| Finished background jobs and their schedule records | 1 day |
| Failed background jobs | 7 days |
| Notifications, and the record of which were sent | 30 days, unless still waiting on you |
| Sent reviews, and drafts you haven't touched | 30 days |
| Echo's own Claude runs, and hook signals from ended sessions | 1 day after they end |
| Find me work's ticket summaries | 14 days, or until the ticket's taken and moved on |

PRs and Jira tickets are replaced on every sync, and your settings are kept until you change them.

## Where things live

| What | Where |
|---|---|
| Echo's database | `storage/` in the project |
| Notifier app, notifier log, copies of repos | `~/Library/Application Support/Echo` (macOS) or `~/.local/share/echo` |
| Claude Code sessions and transcripts (read only) | `~/.claude` |
| Hooks (only if you install them) | `~/.claude/settings.json`, backed up first |
| The background service (`bin/service`) | a launchd agent (macOS) or systemd user service (Linux) at http://localhost:4747 |
