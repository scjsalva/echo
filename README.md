# Echo

A local console for everything that needs you while you work with Claude Code. One page shows your live Claude Code sessions, loops and subagents, your GitHub review queue and PRs, and your Jira tickets. It tells you when something is waiting on you.

Echo runs on your Mac and nothing is hosted. It reads Claude Code's own files and talks to GitHub and Jira through the CLIs you're already logged in to, so it never asks for a token.

**[See everything Echo does →](docs/FEATURES.md)**

## What it does

The full list, page by page, is in [docs/FEATURES.md](docs/FEATURES.md).

- **Agents**: every live Claude Code session, with its status, model, tokens, context use, loops and subagents. Brings a session's Terminal or iTerm2 tab to the front, renames it, summarises it, resumes ended sessions or ends one for you.
- **Waiting on you**: blocked agents, review requests, mentions, changes requested on your PRs and Jira assignments, in one list that clears itself when the source does.
- **GitHub**: the review queue for the repos you watch, your own PRs, and your notifications.
- **Jira**: your tickets grouped by status, done tickets, and search across all of Jira.
- **AI reviews**: a GitHub-style diff with a file tree. Claude reads the PR's code and stages review comments, each one verified against the code, with a verdict every run. You commit the comments you want and send the review yourself; nothing is posted until you do.
- **Notifications**: macOS, Linux or Windows notifications, or in-app alerts, for what's waiting on you or whatever you pick.
- **Skills**: each Claude action uses Echo's own skill by default. You can swap in one of yours, or a repo's, for all repos or just one.
- **Inside Claude Code**: your counts on Claude Code's status line, `/echo` to check what's waiting, your PRs, agents and tickets (and mark read, dismiss or jump to an agent), and `/echo-review` to run an AI review from any session. Install it from Settings → Connections.

## Requirements

- macOS (Linux and Windows notifications work too; Terminal focus is macOS only)
- Ruby 3.4.2 and Node 20
- [Claude Code](https://claude.com/claude-code), logged in
- Optional: the [GitHub CLI](https://cli.github.com) (`gh auth login`) for GitHub
- Optional: the [Atlassian CLI](https://developer.atlassian.com/cloud/acli/) (`acli`) for Jira

## Running it

```bash
npm install
bin/setup        # installs gems, prepares the database, then starts Echo at http://localhost:4848
```

After that, `bin/dev` starts it again.

To keep Echo running in the background, starting when you log in:

```bash
bin/service install    # http://localhost:4747
bin/service status | logs | restart | uninstall
```

Connect GitHub and Jira from **Settings → Connections**. Two optional installs live there too: the Claude Code hooks, which make "waiting on you" instant and refresh open pages right away, and **Echo in Claude Code**, which adds the status line and the `/echo` and `/echo-review` skills.

## Privacy

- Everything stays on your machine, in a local SQLite database.
- Echo only reads from GitHub and Jira. The only writes are marking a GitHub notification read and sending a review you submit.
- Claude runs that Echo starts include your own instructions: `~/.claude/CLAUDE.md`, and each repo's `CLAUDE.md` from your clone. **Settings → Claude** lists every file that's sent. Repo instructions are never read from the PR being reviewed.
- AI reviews read the PR's code from your clone, or from a copy Echo keeps. Your branch and working files are never touched. Claude can read the code but not run it.

## Tests

```bash
bin/rails test
npx vitest run
npx vue-tsc --noEmit
```

## Stack

Rails 8 with Vue 3 components mounted in its views, Vite, Tailwind CSS v4, Phosphor icons, SQLite and Solid Queue.
