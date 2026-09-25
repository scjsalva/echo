class ReviewQuestionJob < ApplicationJob
  def perform(comment, question)
    answer = AiReviewer.discuss(comment, question)
    comment.update!(notes: comment.notes + [ { "role" => "you", "text" => question }, { "role" => "claude", "text" => answer } ], asking: false)
  rescue AiReviewer::Error, Github::Cli::Error, Github::Checkout::Error => e
    comment.update!(notes: comment.notes + [ { "role" => "you", "text" => question }, { "role" => "error", "text" => e.message } ], asking: false)
  ensure
    Changes.bump
  end
end
