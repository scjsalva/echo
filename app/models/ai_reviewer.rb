# Runs Claude headless over a PR's diff and stages its findings as comments.
# Nothing is posted: you commit the comments you want, then send the review.
module AiReviewer
  MODEL = "opus"
  TIMEOUT = 15.minutes
  # Claude can read the PR's code but not run it: --restricted drops the tools
  # that run commands and ignores the repo's own Claude settings and hooks.
  TOOLS = [ "--restricted", "--tools", "Read,Grep,Glob", "--allowedTools", "Read,Grep,Glob", "--strict-mcp-config", "--no-session-persistence" ].freeze
  MAX_DIFF_CHARS = 200_000
  SCHEMA = {
    type: "object", required: %w[summary findings],
    properties: {
      summary: { type: "string" },
      findings: {
        type: "array",
        items: {
          type: "object", required: %w[path line side body verified evidence],
          properties: {
            path: { type: "string" }, line: { type: "integer" }, side: { type: "string", enum: %w[LEFT RIGHT] },
            severity: { type: "string", enum: %w[high medium low nit] }, body: { type: "string" },
            verified: { type: "boolean" }, evidence: { type: "string" }
          }
        }
      }
    }
  }.freeze
  # Echo's rules for a review, whichever skill is doing it: these are what the
  # review page relies on.
  RULES = <<~RULES.squish.freeze
    Each finding is one review comment on one line of the diff: use a path and line exactly as numbered in
    the diff (R = new side, L = old side for removed lines). Rate each finding's severity: high (breaks
    something or must be fixed before merging), medium (likely to cause problems), low (worth fixing but not
    urgent), or nit (minor). If nothing is worth raising, return no findings.
    You're in a checkout of the PR's latest commit and can only read it. Every finding must be verified: read
    the code it depends on and confirm the problem is real. In evidence, name the files and lines you read
    and what they show. Set verified to true only when the code confirms it; anything that depends on a
    guess, or on something the repo can't show, is left out.
    The summary is required and never empty: give your overall verdict in one or two sentences and say what
    you checked. When there's nothing to raise, say that it looks good to approve and why.
  RULES
  QUESTION_RULES = <<~RULES.squish.freeze
    You're in a checkout of the PR's latest commit and can only read it. Only state what you have verified by
    reading the code, and cite the file and line for each claim. If something can't be confirmed from the
    repo, say so plainly instead of guessing.
  RULES

  class Error < StandardError; end

  def self.run(review)
    pr = GithubPullRequest.find_by(key: review.pr_key)&.data || {}
    files = Github::PullRequestFiles.fetch(review.repo, review.number)
    result = ask(prompt(pr, files), Github::Checkout.for_pull_request(review.repo, review.number), repo: review.repo, ref: review.pr_key)
    findings = Array(result["findings"])
    # A run always answers, so an empty one means something went wrong rather than "all good".
    raise Error, "Claude finished without saying anything, so this review can't be trusted. Try again." if result["summary"].blank?

    verified, unverified = findings.partition { it["verified"] == true && it["evidence"].present? }
    on_diff, off_diff = verified.partition { Github::PullRequestFiles.commentable?(files, path: it["path"], line: it["line"], side: it["side"]) }
    on_diff.each do |f|
      review.comments.create!(path: f["path"], line: f["line"], side: f["side"], body: f["body"], severity: f["severity"],
        evidence: f["evidence"], author: "ai")
    end

    # What happened to every finding, so "no comments" is never ambiguous.
    left_out = unverified.map { it.slice("path", "line", "body").merge("reason" => "Claude couldn't confirm it in the code") } +
      off_diff.map { it.slice("path", "line", "body").merge("reason" => "Not on a line in this diff") }
    review.update!(ai_report: { "summary" => result["summary"].to_s, "added" => on_diff.size, "left_out" => left_out })
  end

  # The diff with every line numbered the way GitHub does, so the answer can point at real lines.
  def self.prompt(pr, files)
    diff = files.map do |file|
      lines = file[:hunks].flat_map do |hunk|
        [ hunk[:header] ] + hunk[:lines].map do |l|
          number = l[:kind] == "del" ? "L#{l[:old]}" : "R#{l[:new]}"
          "#{number.ljust(7)}#{{ 'add' => '+', 'del' => '-', 'context' => ' ' }[l[:kind]]} #{l[:text]}"
        end
      end
      "### #{file[:path]} (#{file[:status]})\n#{file[:too_large] ? '(diff too large to show)' : lines.join("\n")}"
    end.join("\n\n").truncate(MAX_DIFF_CHARS, omission: "\n…(rest of the diff left out)")

    "# #{pr['title']}\n\n#{pr['description'] || pr['summary']}\n\n## Diff\n\n#{diff}"
  end

  def self.ask(input, checkout, repo:, ref:)
    command = [ "claude", "-p", "--model", MODEL, "--output-format", "json", "--json-schema", SCHEMA.to_json, *TOOLS,
      "--system-prompt", system_prompt("ai_review", RULES, repo:) ]
    output, status = ClaudeCode::Headless.run(command, input:, chdir: checkout, timeout: TIMEOUT, purpose: "ai_review", ref:)
    raise Error, output.strip.truncate(300) unless status.success?

    result = JSON.parse(output.lines.find { it.start_with?("{") } || "{}")
    raise Error, result["result"].to_s.truncate(300) if result["is_error"]

    result["structured_output"] || raise(Error, "Claude didn't return a review")
  rescue ClaudeCode::Headless::Timeout
    raise Error, "The review took longer than #{TIMEOUT.inspect}"
  rescue JSON::ParserError
    raise Error, "Claude's answer couldn't be read"
  end

  # A follow-up question about one comment, e.g. "is this really a bug?" or "make it shorter".
  def self.discuss(comment, question)
    files = Github::PullRequestFiles.fetch(comment.review.repo, comment.review.number)
    file = files.find { it[:path] == comment.path } || { hunks: [] }
    number = comment.side == "LEFT" ? :old : :new
    nearby = file[:hunks].flat_map { it[:lines] }.select { (it[number].to_i - comment.line).abs <= 12 }
      .map { "#{it[number] || ' '} #{{ 'add' => '+', 'del' => '-', 'context' => ' ' }[it[:kind]]} #{it[:text]}" }
    history = comment.notes.map { "#{it['role']}: #{it['text']}" }.join("\n")
    input = "File #{comment.path}, line #{comment.line}:\n#{nearby.join("\n")}\n\nDraft review comment:\n#{comment.body.presence || "(none yet: the reviewer is asking about the line first)"}\n\n" \
            "#{history.presence && "Earlier discussion:\n#{history}\n\n"}Question: #{question}"

    checkout = Github::Checkout.for_pull_request(comment.review.repo, comment.review.number)
    command = [ "claude", "-p", "--model", MODEL, *TOOLS, "--system-prompt", system_prompt("review_question", QUESTION_RULES, repo: comment.review.repo) ]
    output, status = ClaudeCode::Headless.run(command, input:, chdir: checkout, timeout: 10.minutes, purpose: "review_question", ref: comment.review.pr_key)
    raise Error, output.strip.truncate(300) unless status.success?

    output.strip
  rescue ClaudeCode::Headless::Timeout
    raise Error, "Claude took too long to answer"
  end

  # The chosen skill's instructions, then Echo's rules for the action, then your own context.
  def self.system_prompt(action, rules, repo:)
    [ Skills.for(action, repo:).instructions, "## Echo's rules\n\n#{rules}", ClaudeCode::Context.prompt(repo:) ].compact_blank.join("\n\n")
  end

  private_class_method :prompt, :ask
end
