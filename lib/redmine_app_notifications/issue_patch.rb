# frozen_string_literal: true

module RedmineAppNotifications
  module IssuePatch
    def self.prepended(base)
      base.class_eval do
        after_create :ran_create_app_notifications
      end
    end

    private

    def ran_create_app_notifications
      return unless RedmineAppNotifications::Settings.enabled?('issue_added')

      RedmineAppNotifications::Delivery.deliver(
        issue: self,
        author_id: author_id,
        journal: nil,
        recipients: (notified_users + notified_watchers).uniq
      )
    rescue StandardError => e
      Rails.logger.error("[redmine_app_notifications] issue create notify failed: #{e.class}")
    end
  end
end
