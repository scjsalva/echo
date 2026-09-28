class RetentionJob < ApplicationJob
  def perform
    removed = Retention.run
    Rails.logger.info("Retention: removed #{removed.select { |_, n| n.to_i.positive? }.map { |k, n| "#{n} #{k}" }.join(', ').presence || 'nothing'}")
  end
end
