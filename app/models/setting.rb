# Key/value preferences for this Echo install.
class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true

  def self.[](key) = find_by(key:)&.value

  def self.[]=(key, value)
    value.nil? ? where(key:).delete_all : find_or_initialize_by(key:).update!(value:)
  end
end
