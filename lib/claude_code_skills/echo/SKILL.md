---
name: echo
description: Check Echo, the user's local console for Claude Code sessions, GitHub and Jira. Shows what's waiting on them, unread notifications, the PR review queue, live agents and Jira tickets, and can mark notifications read, dismiss waiting items, or bring an agent's terminal forward. Use when the user asks what needs them, about their review queue, notifications, agents, or a Jira ticket.
argument-hint: "[waiting | inbox | prs | agents | jira KEY | read ID | dismiss KEY | focus AGENT]"
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
| `prs` or `queue` | `curl -s {{BASE_URL}}/api/cli/prs` |
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

For an AI review of a PR, use the `echo-review` skill. Nothing here posts to GitHub or Jira: reviews are only sent from Echo's own review page.
