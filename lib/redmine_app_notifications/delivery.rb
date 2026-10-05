# frozen_string_literal: true

module RedmineAppNotifications
  # Creates in-app rows for an already-decided recipient list.
  # Callers check event settings first. This module drops anyone who cannot
  # see the issue, including private issues, private projects, and private notes.
  module Delivery
    module_function

    def deliver(issue:, author_id:, journal:, recipients:)
      return unless issue.is_a?(Issue)

      Array(recipients).each do |user|
        next unless user.is_a?(User)
        next if user.id == author_id
        next unless user.app_notification_enabled?
        next unless visible?(issue, user, journal)

        AppNotification.record!(
          journal_id: journal&.id,
          issue_id: issue.id,
          author_id: author_id,
          recipient_id: user.id,
          viewed: false
        )
      end
    end

    def visible?(issue, user, journal)
      return false unless issue.visible?(user)
      return true if journal.nil? || !journal.private_notes?
      return true if user.admin? || journal.user_id == user.id

      user.allowed_to?(:view_private_notes, issue.project)
    end
  end
end
