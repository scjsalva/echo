---
name: echo
description: Check Echo, the user's local console for Claude Code sessions, GitHub and Jira. Shows what's waiting on them, unread notifications, the PR review queue, their own PRs, any PR in detail, live agents and Jira tickets, runs AI reviews, and can mark notifications read, dismiss waiting items, or bring an agent's terminal forward. Use when the user asks what needs them, about their review queue, notifications, agents, or a Jira ticket.
argument-hint: "[waiting | inbox | prs | mine | pr PR | review PR | agents | jira KEY | read ID | dismiss KEY | focus AGENT]"
allowed-tools: Bash(curl -s *)
---
<!-- Installed by Echo. Echo keeps this file up to date and removes it when uninstalled. -->

Echo runs on this machine at {{BASE_URL}}. Every command below is a `curl` to it that returns short plain text. If curl can't connect, tell the user "Echo isn't running" and stop.

Pick the command from the arguments ($ARGUMENTS). With no arguments, show the summary.

## Reads

| Arguments | Command |
|---|---|
| (none) | `curl -s {{BASE_URL}}/api/cli/summary` |
| `waiting` | `curl -s {{BASE_URL}}/api/cli/waiting` |
| `inbox` or `notifications` | `curl -s {{BASE_URL}}/api/cli/inbox` |
| `prs` or `queue` | `curl -s {{BASE_URL}}/api/cli/prs` (the review queue) |
| `mine` | `curl -s {{BASE_URL}}/api/cli/mine` (your own open PRs) |
| `pr PR` | `curl -s -G --data-urlencode "ref=PR" {{BASE_URL}}/api/cli/pr` (one PR in full, with its unresolved threads) |
| `agents` | `curl -s {{BASE_URL}}/api/cli/agents` |
| `jira KEY` | `curl -s {{BASE_URL}}/api/cli/jira/KEY` |

Show the result as it is, lightly tidied. Don't add commentary unless the user asks for it.

## Actions

Only when the user asks for them. The ids and keys are the `[...]` values in the lists above.

| Arguments | Command |
|---|---|
| `read ID` (or `read all`) | `curl -s -X POST --data-urlencode "id=ID" {{BASE_URL}}/api/cli/read` |
| `dismiss KEY` | `curl -s -X POST --data-urlencode "key=KEY" {{BASE_URL}}/api/cli/dismiss` |
| `focus AGENT` (id or name) | `curl -s -X POST --data-urlencode "agent=AGENT" {{BASE_URL}}/api/cli/focus` |

## Review a PR

`review PR` runs an AI review in Echo. PR can be `#123`, `123`, `repo#123`, `owner/repo#123` or a GitHub link.

1. Start it: `curl -s -X POST --data-urlencode "pr=PR" {{BASE_URL}}/api/cli/reviews`. The first line says `Started review <id> of <pr>`. If it says the PR can't be found, is merged, or is in more than one repo, tell the user and stop.
2. Wait: `curl -s -m 120 "{{BASE_URL}}/api/cli/reviews/<id>?wait=110"`. Each call holds up to about 110 seconds and returns early when it finishes. Repeat while the first line ends in `queued` or `running`; reviews take 2 to 10 minutes.
3. Show the verdict and staged comments as they are, or the error if it failed.

Nothing here posts to GitHub or Jira: reviews are only sent from Echo's own review page, which is the link in the output.
