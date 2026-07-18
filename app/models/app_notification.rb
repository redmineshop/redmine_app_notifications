# frozen_string_literal: true

class AppNotification < ActiveRecord::Base
  self.table_name = 'app_notifications'

  belongs_to :recipient, class_name: 'User', foreign_key: 'recipient_id', optional: true
  belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true
  belongs_to :issue, optional: true
  belongs_to :journal, optional: true

  scope :for_user, ->(user) { where(recipient_id: user.id) }
  scope :unread, -> { where(viewed: false) }
  scope :recent_first, -> { order(created_on: :desc) }

  before_create :set_created_on

  def self.unread_count_for(user)
    return 0 unless user&.logged?

    for_user(user).unread.count
  rescue StandardError
    0
  end

  def edited?
    journal_id.present?
  end

  def mark_viewed!
    update!(viewed: true) unless viewed?
  end

  def message_text
    issue_ref = issue ? "##{issue.id}" : '#?'
    author_name = author&.name || I18n.t(:label_user)
    if edited?
      I18n.t(:text_issue_updated, id: issue_ref, author: author_name)
    else
      I18n.t(:text_issue_added, id: issue_ref, author: author_name)
    end
  end

  def project_name
    issue&.project&.name.to_s
  end

  private

  def set_created_on
    self.created_on ||= Time.current
  end
end
