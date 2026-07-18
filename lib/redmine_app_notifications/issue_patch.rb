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

      recipients = (notified_users + notified_watchers).uniq
      recipients.each do |user|
        next if user.id == author_id
        next unless user.app_notification_enabled?

        AppNotification.create(
          issue_id: id,
          author_id: author_id,
          recipient_id: user.id,
          viewed: false
        )
      end
    rescue StandardError => e
      Rails.logger.error("[redmine_app_notifications] issue create notify failed: #{e.message}")
    end
  end
end
