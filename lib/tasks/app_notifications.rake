# frozen_string_literal: true

require_relative '../redmine_app_notifications/email_fallback'

namespace :redmine do
  namespace :app_notifications do
    desc 'Email unread in-app notifications older than 24 hours (when email fallback is enabled)'
    task email_fallback: :environment do
      result = RedmineAppNotifications::EmailFallback.deliver!
      if result.skipped
        puts 'Email fallback is disabled in plugin settings. Skipping.'
      else
        puts "Email fallback processed #{result.considered} recipient(s); sent #{result.sent} mail(s)."
      end
    end
  end
end
