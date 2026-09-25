# What Claude Code's hooks last reported about a session, mainly whether it's
# blocked on you (a permission request or a question) right now.
class SessionSignal < ApplicationRecord
  CLEARING_EVENTS = %w[UserPromptSubmit PostToolUse Stop SessionEnd].freeze
  BLOCKING_NOTIFICATIONS = { "permission_prompt" => nil, "elicitation_dialog" => "Claude is asking you a question" }.freeze

  # Applies one hook event. Returns whether anything a page shows could have changed.
  def self.record(event)
    session_id = event["session_id"].presence or return false
    signal = find_or_initialize_by(session_id:)
    name = event["hook_event_name"]
    signal.assign_attributes(last_event: name, last_event_at: Time.current)

    if name == "PermissionRequest"
      signal.block(permission_text(event))
    elsif name == "Notification" && BLOCKING_NOTIFICATIONS.key?(event["notification_type"])
      # PermissionRequest carries the detail; keep it rather than the generic notification text.
      signal.block(BLOCKING_NOTIFICATIONS[event["notification_type"]] || event["message"]) unless signal.needs.present?
    elsif CLEARING_EVENTS.include?(name)
      signal.needs = nil
    end

    signal.save!
    true
  end

  # "Allow Bash(git push origin main)", the way Claude Code phrases permission rules.
  # AskUserQuestion goes through permissions too, but it's a question, not a request.
  # Subagents report through their parent session, with their own agent id and type.
  def self.permission_text(event)
    text = if event["tool_name"] == "AskUserQuestion"
      BLOCKING_NOTIFICATIONS["elicitation_dialog"]
    else
      input = event["tool_input"].is_a?(Hash) ? event["tool_input"] : {}
      detail = input.values_at("command", "file_path", "url", "pattern", "description").compact.first.to_s.squish.truncate(160)
      "Allow #{event['tool_name'] || 'a tool'}#{"(#{detail})" if detail.present?}"
    end
    event["agent_id"].present? ? "#{text} · #{event['agent_type'].presence || 'a'} subagent" : text
  end

  def block(text)
    self.needs = text
    self.needs_at = Time.current
  end
end
