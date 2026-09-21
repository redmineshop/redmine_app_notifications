# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)
require File.expand_path('../../lib/redmine_app_notifications/email_fallback', __dir__)
require 'rake'

class EmailFallbackTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :roles, :members, :member_roles,
           :issues, :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  class RecordingMailer
    Delivery = Struct.new(:to, :from, :subject, :body, :content_type, keyword_init: true)

    attr_reader :deliveries

    def initialize
      @deliveries = []
    end

    def mail(headers)
      delivery = Delivery.new(
        to: headers[:to],
        from: headers[:from],
        subject: headers[:subject],
        body: headers[:body],
        content_type: headers[:content_type]
      )
      deliveries = @deliveries
      delivery.define_singleton_method(:deliver_now) { deliveries << self }
      delivery
    end
  end

  class RaisingMailer < RecordingMailer
    def initialize(fail_to:)
      super()
      @fail_to = fail_to
    end

    def mail(headers)
      delivery = super
      return delivery unless headers[:to] == @fail_to

      delivery.define_singleton_method(:deliver_now) { raise 'smtp down' }
      delivery
    end
  end

  def setup
    @now = Time.zone.parse('2026-09-22 12:00:00')
    @user = User.find(2)
    @other = User.find(3)
    @issue = Issue.find(1)
    @other_issue = Issue.where.not(id: @issue.id).first
    AppNotification.delete_all
    @previous_settings = Setting.plugin_redmine_app_notifications
    @previous_mail_from = Setting.mail_from
    Setting.mail_from = 'redmine@example.test'
    enable_fallback!
  end

  def teardown
    Setting.plugin_redmine_app_notifications = @previous_settings if @previous_settings
    Setting.mail_from = @previous_mail_from
  end

  def test_rake_task_delegates_to_email_fallback
    source = File.read(
      Rails.root.join('plugins/redmine_app_notifications/lib/tasks/app_notifications.rake')
    )
    assert_match(/task email_fallback: :environment/, source)
    assert_match(/RedmineAppNotifications::EmailFallback\.deliver!/, source)
  end

  def test_rake_task_is_a_noop_when_setting_is_off
    Setting.plugin_redmine_app_notifications =
      RedmineAppNotifications::Settings.defaults.merge('enable_email_fallback' => '0')
    create_notification(@user, @issue, @now - 2.days)
    task = email_fallback_task
    deps = task.prerequisites.dup
    # Avoid re-entering the Rails environment task from inside the test process.
    task.prerequisites.clear
    task.reenable

    assert_output(/disabled in plugin settings/) do
      task.invoke
    end
    assert_equal false, AppNotification.last.viewed?
  ensure
    if defined?(task) && task
      task.reenable
      task.prerequisites.concat(deps) if deps
    end
  end

  def test_setting_off_does_not_deliver
    Setting.plugin_redmine_app_notifications =
      RedmineAppNotifications::Settings.defaults.merge('enable_email_fallback' => '0')
    create_notification(@user, @issue, @now - 2.days)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert result.skipped
    assert_equal 0, result.sent
    assert_empty mailer.deliveries
  end

  def test_setting_on_emails_only_unread_older_than_24_hours
    create_notification(@user, @issue, @now - 25.hours)
    fresh = create_notification(@user, @other_issue, @now - 23.hours)
    viewed = create_notification(@user, @issue, @now - 3.days, viewed: true)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_not result.skipped
    assert_equal 1, result.sent
    assert_equal 1, mailer.deliveries.size
    body = mailer.deliveries.first.body
    assert_match(/##{@issue.id}(?!\d)/, body)
    assert_no_match(/##{fresh.issue_id}(?!\d)/, body)
    assert_equal 'text/plain; charset=UTF-8', mailer.deliveries.first.content_type
    assert_equal @user.mail, mailer.deliveries.first.to
    assert viewed.reload.viewed?
    assert AppNotification.unread.exists?(recipient_id: @user.id, issue_id: @issue.id)
  end

  def test_does_not_include_another_users_rows
    create_notification(@user, @issue, @now - 2.days)
    create_notification(@other, @other_issue, @now - 2.days)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_equal 2, result.sent
    own = mailer.deliveries.find { |delivery| delivery.to == @user.mail }
    theirs = mailer.deliveries.find { |delivery| delivery.to == @other.mail }
    assert own
    assert theirs
    assert_includes own.body, "##{@issue.id}"
    assert_not_includes own.body, "##{@other_issue.id}"
    assert_includes theirs.body, "##{@other_issue.id}"
    assert_not_includes theirs.body, "##{@issue.id}"
  end

  def test_skips_rows_the_recipient_cannot_see
    project = @issue.project
    was_public = project.is_public
    project.update_column(:is_public, false)
    outsider = User.new(
      login: 'notify-outsider',
      firstname: 'Out',
      lastname: 'Sider',
      mail: 'notify-outsider@example.test',
      status: User::STATUS_ACTIVE
    )
    outsider.password = 'Outsider1!'
    outsider.password_confirmation = 'Outsider1!'
    assert outsider.save, outsider.errors.full_messages.join(', ')
    assert_not @issue.reload.visible?(outsider)

    create_notification(outsider, @issue, @now - 2.days)
    create_notification(@user, @other_issue, @now - 2.days)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_equal 1, result.sent
    assert_equal [@user.mail], mailer.deliveries.map(&:to)
    assert_not_includes mailer.deliveries.first.body, "##{@issue.id}"
    assert_includes mailer.deliveries.first.body, "##{@other_issue.id}"
  ensure
    project.update_column(:is_public, was_public) if project && !was_public.nil?
  end

  def test_skips_mail_addresses_with_line_breaks
    address = @user.email_address
    original = address.address
    address.update_column(:address, "user@example.test\nBcc: evil@example.test")
    create_notification(@user, @issue, @now - 2.days)
    create_notification(@other, @other_issue, @now - 2.days)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_equal 1, result.sent
    assert_equal [@other.mail], mailer.deliveries.map(&:to)
  ensure
    address.update_column(:address, original) if address && original
  end

  def test_one_recipient_failure_does_not_block_others
    create_notification(@user, @issue, @now - 2.days)
    create_notification(@other, @other_issue, @now - 2.days)
    mailer = RaisingMailer.new(fail_to: @user.mail)

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_equal 1, result.sent
    assert_equal [@other.mail], mailer.deliveries.map(&:to)
  end

  def test_blank_mail_from_sends_nothing
    Setting.mail_from = ''
    create_notification(@user, @issue, @now - 2.days)
    mailer = RecordingMailer.new

    result = RedmineAppNotifications::EmailFallback.deliver!(now: @now, mailer: mailer)

    assert_not result.skipped
    assert_equal 0, result.sent
    assert_empty mailer.deliveries
  end

  private

  def enable_fallback!
    Setting.plugin_redmine_app_notifications =
      RedmineAppNotifications::Settings.defaults.merge('enable_email_fallback' => '1')
  end

  def create_notification(user, issue, created_on, viewed: false)
    AppNotification.create!(
      issue_id: issue.id,
      author_id: User.find(1).id,
      recipient_id: user.id,
      viewed: viewed,
      created_on: created_on
    )
  end

  def email_fallback_task
    name = 'redmine:app_notifications:email_fallback'
    unless Rake::Task.task_defined?(name)
      load Rails.root.join('plugins/redmine_app_notifications/lib/tasks/app_notifications.rake')
    end
    Rake::Task[name]
  end
end
