# Atlassian Document Format (the JSON Jira uses for descriptions and comments) to plain text.
module Jira::Adf
  BLOCKS = %w[paragraph heading blockquote codeBlock panel rule].freeze

  def self.to_text(node)
    render(node).gsub(/\n{3,}/, "\n\n").strip
  end

  def self.mentions?(node, account_id)
    return false unless node.is_a?(Hash) && account_id

    (node["type"] == "mention" && node.dig("attrs", "id") == account_id) || Array(node["content"]).any? { mentions?(it, account_id) }
  end

  def self.render(node)
    return "" unless node.is_a?(Hash)

    case node["type"]
    when "text" then node["text"].to_s
    when "mention" then node.dig("attrs", "text").to_s.then { it.start_with?("@") ? it : "@#{it}" }
    when "emoji" then node.dig("attrs", "text").to_s
    when "hardBreak" then "\n"
    when "inlineCard", "blockCard" then node.dig("attrs", "url").to_s
    when "bulletList", "orderedList"
      items = Array(node["content"]).each_with_index.map do |item, i|
        "#{node['type'] == 'orderedList' ? "#{i + 1}." : '-'} #{render(item).strip.gsub(/\n+/, "\n   ")}"
      end
      "#{items.join("\n")}\n\n"
    else
      inner = Array(node["content"]).map { render(it) }.join
      BLOCKS.include?(node["type"]) ? "#{inner}\n\n" : inner
    end
  end

  private_class_method :render
end
