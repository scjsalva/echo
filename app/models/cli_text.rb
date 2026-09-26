# Echo as short plain text, for the status line and the /echo skills inside
# Claude Code. Kept compact so reading it costs few tokens.
module CliText
  LIMIT = 10

  def self.status(dashboard = Dashboard.current)
    parts = {
      "waiting" => dashboard.waiting_items.count { it[:status] == "open" },
      "unread" => (dashboard.github_notifications + dashboard.jira_notifications).count { it[:unread] },
      "to review" => dashboard.unapproved_reviews.size
    }.select { |_, count| count.positive? }
    parts.empty? ? "Echo: all clear" : "Echo: #{parts.map { |label, count| "#{count} #{label}" }.join(' · ')}"
  end

  def self.summary(dashboard = Dashboard.current)
    [ status(dashboard), waiting(dashboard, limit: 5), inbox(dashboard, limit: 5), prs(dashboard, limit: 5) ].join("\n\n")
  end

  def self.waiting(dashboard = Dashboard.current, limit: LIMIT)
    items = dashboard.waiting_items.select { it[:status] == "open" }
    list("Waiting on you", items, limit) do |item|
      "- [#{item[:key]}] #{item[:label]}: #{item[:title]}#{" · #{item[:actor]}" if item[:actor]}#{" · \"#{item[:detail].truncate(160)}\"" if item[:detail]} · #{ago(item[:at])}"
    end
  end

  def self.inbox(dashboard = Dashboard.current, limit: LIMIT)
    github = dashboard.github_notifications.select { it[:unread] }.map do |n|
      [ n[:at], "- [#{n[:id]}] #{n[:pr_key]} #{n[:title]}: #{Github::NotificationText.for(reason: n[:reason], actor: n[:actor], body: n[:body]&.truncate(160), mine: n[:mine])} · #{ago(n[:at])}" ]
    end
    jira = dashboard.jira_notifications.select { it[:unread] }.map do |n|
      [ n[:at], "- [#{n[:id]}] #{n[:key]}: #{Jira::NotificationText.for(kind: n[:kind], actor: n[:actor], body: n[:body]&.truncate(160))} · #{ago(n[:at])}" ]
    end
    list("Unread notifications", (github + jira).sort_by { -it.first.to_i }, limit, &:last)
  end

  def self.prs(dashboard = Dashboard.current, limit: LIMIT)
    list("Review queue", dashboard.unapproved_reviews, limit) do |pr|
      flags = [ ("requested from you" if pr[:requested_from_me]), pr[:ci], pr[:review_state]&.tr("_", " ") ].compact.join(", ")
      "- #{pr[:key]} \"#{pr[:title]}\" by #{pr[:author]} (#{flags}) · opened #{ago(pr[:opened])}"
    end
  end

  def self.agents(dashboard = Dashboard.current)
    list("Agents", dashboard.agents, 50) do |a|
      "- [#{a[:id]}] #{a[:name]} · #{a[:status]}#{" · needs: #{a[:needs]}" if a[:needs]} · #{a[:cwd]}#{" · #{a[:branch]}" if a[:branch]}"
    end
  end

  def self.mine(dashboard = Dashboard.current)
    list("Your open PRs", dashboard.pull_requests.select { it[:mine] }.sort_by { it[:opened].to_s }.reverse, 30) do |pr|
      state = pr[:draft] ? "draft" : pr[:review_state]&.tr("_", " ")
      "- #{pr[:key]} \"#{pr[:title]}\" (#{[ state, pr[:ci] ].compact.join(', ')}) · opened #{ago(pr[:opened])}"
    end
  end

  # One PR in full: where it stands, who reviewed it, its description and the
  # review threads still unresolved. Works for PRs Echo doesn't sync too.
  def self.pull_request(key, dashboard = Dashboard.current)
    repo, number = key.split("#")
    pr = dashboard.pull_requests.find { it[:key] == key } ||
      Github::PullRequest.from_rest(Github::Cli.run("api", "repos/#{repo}/pulls/#{number}", json: true), me: Github::Connection.login)
    reviews = Array(pr[:reviews]).map { "#{it[:login]} #{it[:state].to_s.tr('_', ' ')}" }
    threads = Github::ReviewThreads.unresolved(repo, number)

    lines = [
      "#{pr[:key]} \"#{pr[:title]}\" by #{pr[:author]}#{' (draft)' if pr[:draft]}",
      "CI #{pr[:ci]} · #{pr[:review_state].to_s.tr('_', ' ')} · +#{pr[:additions]} -#{pr[:deletions]} in #{pr[:changed_files]} files · opened #{ago(pr[:opened])}",
      pr[:url], "Review in Echo: #{DesktopNotification.base_url}/reviews/#{repo}/#{number}"
    ]
    lines << "Reviews: #{reviews.join(', ')}" if reviews.any?
    lines << "\n#{pr[:description].to_s.truncate(1_500)}" if pr[:description].present?
    lines << "\nUnresolved threads (#{threads.size}):" if threads.any?
    threads.first(LIMIT).each do |t|
      first = t[:comments].first
      where = t[:outdated] ? "#{t[:path]} (older code)" : "#{t[:path]}:#{t[:line]}"
      lines << "- #{where} · #{first&.dig(:author)}: #{first&.dig(:body).to_s.squish.truncate(200)} (#{t[:comments].size} comment#{'s' unless t[:comments].size == 1})"
    end
    lines.join("\n")
  end

  def self.ticket(key, dashboard = Dashboard.current)
    t = dashboard.jira_tickets.find { it[:key].casecmp?(key) } ||
      Jira::TicketSearch.page(site: Jira::Connection.status[:site], query: key)[:items].find { it[:key].casecmp?(key) }
    return "No Jira ticket #{key}" unless t

    "#{t[:key]} \"#{t[:title]}\" · #{t[:type]} · #{t[:status]} · assignee #{t[:assignee] || 'nobody'}\n#{t[:url]}\n\n#{t[:description].to_s.truncate(2_000)}"
  end

  def self.review(review)
    url = "#{DesktopNotification.base_url}/reviews/#{review.repo}/#{review.number}"
    lines = [ "Review of #{review.pr_key}: #{review.ai_status}", url ]
    lines << "Error: #{review.ai_error}" if review.ai_status == "failed"
    if review.ai_status == "done" && (report = review.ai_report)
      lines << "\nVerdict: #{report['summary']}"
      staged = review.comments.where(author: "ai").where.not(state: "removed")
      lines << "\nComments staged (#{staged.size}):" if staged.any?
      staged.each { lines << "- #{it.path}:#{it.line} [#{it.severity || 'note'}] #{it.body.squish.truncate(300)}" }
      lines << "\n#{report['left_out'].size} finding(s) left out as unverified or off the diff." if report["left_out"].present?
      lines << "\nNothing is posted until you send the review from Echo."
    end
    lines.join("\n")
  end

  class Ambiguous < StandardError; end

  # "owner/repo#123", "repo#123" (one of your watched repos), a GitHub PR link,
  # or just "#123" / "123" when only one PR Echo syncs has that number.
  def self.pr_key(ref)
    ref = ref.to_s.strip
    if (m = ref.match(%r{github\.com/([\w.-]+/[\w.-]+)/pull/(\d+)}) || ref.match(%r{\A([\w.-]+/[\w.-]+)#(\d+)\z}))
      "#{m[1]}##{m[2]}"
    elsif (m = ref.match(/\A([\w.-]+)#(\d+)\z/))
      repo = Github::Preferences.repos.find { it.split("/").last == m[1] } or return
      "#{repo}##{m[2]}"
    elsif (m = ref.match(/\A#?(\d+)\z/))
      keys = GithubPullRequest.pluck(:key).select { it.end_with?("##{m[1]}") }
      # Not synced (e.g. someone's draft): ask GitHub which watched repos have it.
      keys = Github::Preferences.repos.map { "#{it}##{m[1]}" }.select { pr_exists?(it) } if keys.empty?
      raise Ambiguous, "More than one repo has a PR ##{m[1]}: #{keys.join(', ')}. Say which one, e.g. #{keys.first}." if keys.many?

      keys.first
    end
  end

  def self.pr_exists?(key)
    repo, number = key.split("#")
    Github::Cli.run("api", "repos/#{repo}/pulls/#{number}", "--jq", ".number").strip == number
  rescue Github::Cli::Error
    false
  end

  def self.list(title, items, limit, &line)
    return "#{title}: none" if items.empty?

    more = items.size > limit ? "\n…and #{items.size - limit} more in Echo" : ""
    "#{title} (#{items.size}):\n#{items.first(limit).map(&line).join("\n")}#{more}"
  end

  def self.ago(at)
    time = at.is_a?(String) ? Time.zone.parse(at) : at
    time ? "#{ActionController::Base.helpers.time_ago_in_words(time)} ago" : ""
  end

  private_class_method :list, :ago, :pr_exists?
end
