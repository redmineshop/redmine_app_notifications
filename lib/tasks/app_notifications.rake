# frozen_string_literal: true

namespace :redmine do
  namespace :app_notifications do
    desc 'Email unread in-app notifications older than 24 hours (when email fallback is enabled)'
    task email_fallback: :environment do
      unless RedmineAppNotifications::Settings.email_fallback_enabled?
        puts 'Email fallback is disabled in plugin settings. Skipping.'
        next
      end

      cutoff = 24.hours.ago
      scope = AppNotification.unread.where(created_on: ..cutoff).includes(:recipient, :issue, :author)
      grouped = scope.group_by(&:recipient_id)
      sent = 0

      grouped.each do |_recipient_id, notifications|
        user = notifications.first.recipient
        next unless user&.active? && user.mail.present?

        body = notifications.map { |n| "- #{n.message_text}" }.join("\n")
        ActionMailer::Base.mail(
          to: user.mail,
          from: Setting.mail_from,
          subject: "[Redmine] #{notifications.size} unread notification(s)",
          body: body
        ).deliver_now
        sent += 1
      end

      puts "Email fallback processed #{grouped.size} recipient(s); sent #{sent} mail(s)."
    end
  end
end
