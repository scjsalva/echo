# Rewrites one comment with your rewrite skill; the draft lands in the comment's notes, ready to use.
class ReviewRewriteJob < ApplicationJob
  def perform(comment)
    asked = { "role" => "you", "text" => "Rewrite" }
    comment.update!(notes: comment.notes + [ asked, { "role" => "claude", "text" => Rewriter.rewrite(comment.body) } ], asking: false)
  rescue Rewriter::Error => e
    comment.update!(notes: comment.notes + [ asked, { "role" => "error", "text" => e.message } ], asking: false)
  ensure
    Changes.bump
  end
end
