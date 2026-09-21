# frozen_string_literal: true

module RedmineAppNotifications
  # Sends one plain-text digest per recipient for unread in-app rows older than 24 hours.
  # The rake task is a thin wrapper around this class so tests can stub delivery.
  class EmailFallback
    CUTOFF_AGE = 24.hours

    Result = Struct.new(:skipped, :considered, :sent, keyword_init: true)

    def self.deliver!(now: Time.current, mailer: ActionMailer::Base)
      new(now: now, mailer: mailer).deliver!
    end

    def initialize(now:, mailer:)
      @now = now
      @mailer = mailer
    end

    def deliver!
      unless Settings.email_fallback_enabled?
        return Result.new(skipped: true, considered: 0, sent: 0)
      end

      from = Setting.mail_from.to_s
      if from.blank? || header_unsafe?(from)
        Rails.logger.error('[redmine_app_notifications] email fallback skipped: mail_from is blank or unsafe')
        return Result.new(skipped: false, considered: 0, sent: 0)
      end

      cutoff = @now - CUTOFF_AGE
      rows = AppNotification.unread.where(created_on: ..cutoff).includes(:recipient, :issue, :author).to_a
      considered = 0
      sent = 0

      rows.group_by(&:recipient_id).each do |recipient_id, notifications|
        considered += 1
        user = notifications.first.recipient
        next unless user && user.id == recipient_id && deliverable_user?(user)

        visible = notifications.select { |notification| notification.recipient_id == user.id && visible_to?(notification, user) }
        next if visible.empty?

        body = visible.map { |notification| "- #{notification.message_text}" }.join("\n")
        @mailer.mail(
          to: user.mail,
          from: from,
          subject: "[Redmine] #{visible.size} unread notification(s)",
          body: body,
          content_type: 'text/plain; charset=UTF-8'
        ).deliver_now
        sent += 1
      rescue StandardError => e
        Rails.logger.error(
          "[redmine_app_notifications] email fallback failed for recipient #{recipient_id}: #{e.class}"
        )
      end

      Result.new(skipped: false, considered: considered, sent: sent)
    end

    private

    def deliverable_user?(user)
      return false unless user.active?
      return false if user.mail.blank?
      return false if header_unsafe?(user.mail)

      true
    end

    def visible_to?(notification, user)
      issue = notification.issue
      return false unless issue

      issue.visible?(user)
    rescue StandardError
      false
    end

    def header_unsafe?(value)
      value.to_s.match?(/[\r\n]/)
    end
  end
end
