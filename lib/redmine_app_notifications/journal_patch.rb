# frozen_string_literal: true

module RedmineAppNotifications
  module JournalPatch
    def self.prepended(base)
      base.class_eval do
        after_create :ran_create_app_notifications
      end
    end

    private

    def ran_create_app_notifications
      return unless notify?
      return unless should_notify_for_journal?

      issue = journalized
      return unless issue.is_a?(Issue)

      RedmineAppNotifications::Delivery.deliver(
        issue: issue,
        author_id: user_id,
        journal: self,
        recipients: (notified_users + notified_watchers).uniq
      )
    rescue StandardError => e
      Rails.logger.error("[redmine_app_notifications] journal create notify failed: #{e.class}")
    end

    def should_notify_for_journal?
      settings = RedmineAppNotifications::Settings

      return true if notes.present? && settings.enabled?('issue_note_added')
      return true if new_status.present? && settings.enabled?('issue_status_updated')
      return true if detail_for_attribute('assigned_to_id').present? &&
                     settings.enabled?('issue_assigned_to_updated')
      return true if new_value_for('priority_id').present? &&
                     settings.enabled?('issue_priority_updated')

      # Catch-all only when this journal is not one of the specific event types above.
      return false if notes.present? ||
                      new_status.present? ||
                      detail_for_attribute('assigned_to_id').present? ||
                      new_value_for('priority_id').present?

      settings.enabled?('issue_updated')
    end
  end
end
