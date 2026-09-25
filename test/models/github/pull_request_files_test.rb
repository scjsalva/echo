require "test_helper"

class Github::PullRequestFilesTest < ActiveSupport::TestCase
  PATCH = <<~DIFF.chomp
    @@ -10,4 +10,5 @@ def total
       a = 1
    -  b = 2
    +  b = 3
    +  c = 4
       d = 5
    \\ No newline at end of file
  DIFF

  def files
    Github::Cli.stub(:run, ->(*, **) { [ { "filename" => "app/x.rb", "status" => "modified", "additions" => 2, "deletions" => 1, "changes" => 3, "patch" => PATCH } ] }) do
      Rails.cache.clear
      Github::PullRequestFiles.fetch("acme/app", 1)
    end
  end

  test "numbers each diff line on the old and new side" do
    lines = files.sole[:hunks].sole[:lines]

    assert_equal [ [ "context", 10, 10 ], [ "del", 11, nil ], [ "add", nil, 11 ], [ "add", nil, 12 ], [ "context", 12, 13 ] ],
      lines.map { it.values_at(:kind, :old, :new) }
    assert_equal "def total", files.sole[:hunks].sole[:context]
  end

  test "only lines in the diff can take a comment" do
    assert Github::PullRequestFiles.commentable?(files, path: "app/x.rb", line: 12, side: "RIGHT")
    assert Github::PullRequestFiles.commentable?(files, path: "app/x.rb", line: 11, side: "LEFT")
    assert_not Github::PullRequestFiles.commentable?(files, path: "app/x.rb", line: 40, side: "RIGHT")
    assert_not Github::PullRequestFiles.commentable?(files, path: "app/x.rb", line: 10, side: "LEFT")
  end
end
