require "test_helper"

class Jira::AdfTest < ActiveSupport::TestCase
  DOC = {
    "type" => "doc", "content" => [
      { "type" => "paragraph", "content" => [
        { "type" => "mention", "attrs" => { "id" => "me-1", "text" => "@John Salva" } },
        { "type" => "text", "text" => " can you check?" }, { "type" => "hardBreak" }, { "type" => "text", "text" => "Thanks" }
      ] },
      { "type" => "bulletList", "content" => [
        { "type" => "listItem", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => "one" } ] } ] }
      ] }
    ]
  }.freeze

  test "renders plain text with mentions, line breaks and list items" do
    assert_equal "@John Salva can you check?\nThanks\n\n- one", Jira::Adf.to_text(DOC)
  end

  test "finds mentions of a given account" do
    assert Jira::Adf.mentions?(DOC, "me-1")
    assert_not Jira::Adf.mentions?(DOC, "someone-else")
    assert_not Jira::Adf.mentions?(nil, "me-1")
  end

  test "numbers ordered lists and keeps items on consecutive lines" do
    list = { "type" => "orderedList", "content" => %w[Log\ in Open].map { |t| { "type" => "listItem", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => t } ] } ] } } }

    assert_equal "1. Log in\n2. Open", Jira::Adf.to_text({ "type" => "doc", "content" => [ list ] })
  end
end
