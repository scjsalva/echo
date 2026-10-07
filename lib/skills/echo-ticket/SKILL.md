---
name: echo-ticket
description: Echo's default for Ask Claude on a ticket. Gathers every bit of context a ticket has, from its links, attachments, related tickets, PRs and the code, then evaluates it with you before anyone picks it up.
---

You're helping evaluate a ticket before deciding to pick it up. The brief above is what Echo could gather on its own.
Treat it as a starting point, not the whole story: the context that matters is often in a recording, a linked
ticket, an earlier PR or the code itself.

## 1. Gather everything there is

Work through what the brief points at, with whatever tools this session has. Skip what's clearly irrelevant,
but don't stop at the ticket text.

- **Links.** Open the ones in the brief that could matter, using the right tool for each:
  - GitHub PRs, commits and issues: `gh` (e.g. `gh pr view <url> --comments`, `gh pr diff <url>`).
  - Screen recordings and bug captures (e.g. Jam, Loom): an MCP server for that service if you have one, for
    the transcript, console logs, network requests and screenshots.
  - Design files, docs and wiki pages (e.g. Figma, Confluence, Notion): an MCP server for them if you have one,
    otherwise a web fetch for public pages.
  - Anything else: a web fetch, when it's public.
- **Attachments.** Echo can only list them. If a tool here can reach the ticket's attachments (e.g. an MCP server
  for the issue tracker), look at the ones that matter, such as screenshots, recordings and logs. Otherwise say
  which ones you couldn't see and ask whether the user can share them.
- **Related tickets.** The parent, subtasks and linked tickets are in the brief. Follow up on any whose story
  bears on this one, e.g. a duplicate that already has a fix, or a parent that sets constraints.
- **PRs that mention the ticket.** Check the ones the brief lists: work may already be done, reverted or in review.
- **The code.** Find where the behaviour lives, and the history behind it (`git log`, `git blame`) when the
  ticket is about something that used to work.

Say briefly what you looked at, and anything you couldn't reach. Never guess at what a recording or file says.

## 2. Evaluate it

- What it's asking for, in plain words, and whether that matches what the reporter actually shows.
- Where the change would go, and the approach you'd take, with any alternative worth weighing.
- Risks, unknowns and open questions, including questions for the reporter.
- A rough size.

Verify what you claim against the code and the sources. Say when you're unsure. Keep it as short as it can be
while still giving the user what they need to decide.
