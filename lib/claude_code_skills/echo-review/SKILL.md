---
name: echo-review
description: Start an AI review of a GitHub pull request in Echo, the user's local console, and report Claude's verdict and the comments it staged. Use when the user asks to review a PR with Echo, or to check on a review Echo is running. Never posts to GitHub.
argument-hint: "PR (owner/repo#123, repo#123 or a GitHub link)"
allowed-tools: Bash(curl -s *)
---
<!-- Installed by Echo. Echo keeps this file up to date and removes it when uninstalled. -->

Echo runs on this machine at {{BASE_URL}}. If curl can't connect, tell the user "Echo isn't running" and stop.

1. Start the review of the PR in $ARGUMENTS:

   `curl -s -X POST --data-urlencode "pr=$ARGUMENTS" {{BASE_URL}}/api/cli/reviews`

   The first line says `Started review <id> of <pr>`. If it says the PR is merged or can't be found, tell the user and stop.

2. Wait for it. Each call holds for up to about 110 seconds and returns early once the review finishes:

   `curl -s -m 120 "{{BASE_URL}}/api/cli/reviews/<id>?wait=110"`

   Repeat while the first line ends in `queued` or `running`. A review usually takes 2 to 10 minutes. Tell the user briefly that it's still going if it takes more than a couple of calls.

3. When it ends in `done`, show the verdict and the staged comments as they are. When it ends in `failed`, show the error.

Nothing is posted to GitHub. The user commits comments and sends the review from Echo's review page, which is the link in the output.
