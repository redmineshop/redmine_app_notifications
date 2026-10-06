# frozen_string_literal: true

class AppNotification < ActiveRecord::Base
  self.table_name = 'app_notifications'

  WRITABLE_ATTRIBUTES = %w[
    journal_id
    issue_id
    author_id
    recipient_id
    viewed
    created_on
  ].freeze

  belongs_to :recipient, class_name: 'User', foreign_key: 'recipient_id', optional: true
  belongs_to :author, class_name: 'User', foreign_key: 'author_id', optional: true
  belongs_to :issue, optional: true
  belongs_to :journal, optional: true

  scope :for_user, ->(user) { where(recipient_id: user.id) }
  scope :unread, -> { where(viewed: false) }
  scope :recent_first, -> { order(created_on: :desc) }
  # Merge so an earlier `for_user` constraint is kept. A fresh `where` here would drop it.
  scope :visible_to, ->(user) { merge(AppNotification.visible_scope_for(user)) }

  before_create :set_created_on

  def self.record!(attributes)
    create!(writable_attributes(attributes))
  end

  def self.writable_attributes(attributes)
    attributes.to_h.stringify_keys.slice(*WRITABLE_ATTRIBUTES)
  end

  # Issues the user can see, minus private-note journals they cannot read.
  # `Issue.visible` joins projects, so the subquery selects `issues.id` only.
  def self.visible_scope_for(user)
    return none unless user&.logged?

    visible_issue_ids = Issue.visible(user).unscope(:order).select("#{Issue.table_name}.id")
    scope = where(issue_id: visible_issue_ids)
    return scope if user.admin?

    scope.where.not(id: hidden_private_note_ids_for(user))
  end

  def self.hidden_private_note_ids_for(user)
    allowed_issue_ids = Issue.joins(:project).where(
      Project.allowed_to_condition(user, :view_private_notes)
    ).unscope(:order).select("#{Issue.table_name}.id")

    blocked_journal_ids = Journal.
      where(private_notes: true, journalized_type: 'Issue').
      where.not(user_id: user.id).
      where.not(journalized_id: allowed_issue_ids).
      select(:id)

    where(journal_id: blocked_journal_ids).select(:id)
  end
  private_class_method :hidden_private_note_ids_for

  def self.unread_count_for(user)
    return 0 unless user&.logged?
    return 0 unless table_exists?

    for_user(user).visible_to(user).unread.count
  end

  def edited?
    journal_id.present?
  end

  def mark_viewed!
    update!(viewed: true) unless viewed?
  end

  def visible_to?(user)
    return false unless user&.logged?

    issue_record = issue
    return false unless issue_record&.visible?(user)

    journal_record = journal_id.present? ? journal : nil
    return true if journal_record.nil? || !journal_record.private_notes?
    return true if user.admin? || journal_record.user_id == user.id

    user.allowed_to?(:view_private_notes, issue_record.project)
  end

  def message_text
    issue_ref = issue ? "##{issue.id}" : '#?'
    author_name = author&.name || I18n.t(:label_user)
    key = edited? ? :text_issue_updated : :text_issue_added
    I18n.t(key, id: issue_ref, author: author_name).to_s
  end

  def project_name
    issue&.project&.name.to_s
  end

  private

  def set_created_on
    self.created_on ||= Time.current
  end
end
