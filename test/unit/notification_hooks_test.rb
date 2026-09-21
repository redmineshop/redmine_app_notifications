# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class NotificationHooksTest < ActiveSupport::TestCase
  fixtures :projects, :users, :email_addresses, :user_preferences, :roles, :members,
           :member_roles, :issues, :trackers, :projects_trackers, :issue_statuses,
           :enumerations, :enabled_modules

  def setup
    AppNotification.delete_all
    @author = User.find(2)
    @recipient = User.find(3)
    @author.update!(mail_notification: 'all')
    @recipient.update!(mail_notification: 'all')
    @recipient.pref[:app_notifications] = true
    @recipient.pref.save!
    @previous_settings = Setting.plugin_redmine_app_notifications
    Setting.plugin_redmine_app_notifications = RedmineAppNotifications::Settings.defaults
    User.current = @author
  end

  def teardown
    User.current = nil
    Setting.plugin_redmine_app_notifications = @previous_settings if @previous_settings
  end

  def test_issue_create_notifies_other_members_but_not_the_author
    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Hook create')

    recipient_ids = AppNotification.where(issue_id: issue.id).pluck(:recipient_id)
    assert_includes recipient_ids, @recipient.id
    assert_not_includes recipient_ids, @author.id
    assert AppNotification.where(issue_id: issue.id, recipient_id: @recipient.id, journal_id: nil).exists?
  end

  def test_issue_create_does_nothing_when_issue_added_is_off
    Setting.plugin_redmine_app_notifications =
      RedmineAppNotifications::Settings.defaults.merge('issue_added' => '0')

    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Silent create')

    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_issue_create_skips_users_who_disabled_the_preference
    @recipient.pref[:app_notifications] = false
    @recipient.pref.save!

    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Pref off')

    assert_not_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), @recipient.id
  end

  def test_journal_note_creates_a_notification
    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Needs a note')
    AppNotification.delete_all

    issue.init_journal(@author, 'Please review')
    assert issue.save, issue.errors.full_messages.join(', ')

    rows = AppNotification.where(issue_id: issue.id)
    assert_includes rows.map(&:recipient_id), @recipient.id
    assert_not_includes rows.map(&:recipient_id), @author.id
    assert rows.all? { |row| row.journal_id.present? }
  end

  def test_journal_note_is_skipped_when_note_event_is_off
    issue = Issue.generate!(project_id: 1, author: @author, subject: 'No note event')
    AppNotification.delete_all
    Setting.plugin_redmine_app_notifications =
      RedmineAppNotifications::Settings.defaults.merge(
        'issue_note_added' => '0',
        'issue_updated' => '0'
      )

    issue.init_journal(@author, 'This note should not notify')
    assert issue.save, issue.errors.full_messages.join(', ')

    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_should_notify_for_journal_respects_each_event
    issue = Issue.find(1)
    settings = RedmineAppNotifications::Settings

    note = journal_for(issue, notes: 'hello')
    assert note.send(:should_notify_for_journal?)

    Setting.plugin_redmine_app_notifications =
      settings.defaults.merge('issue_note_added' => '0', 'issue_updated' => '1')
    assert_not note.send(:should_notify_for_journal?)

    status = journal_for(issue, details: [['status_id', '1', '2']])
    Setting.plugin_redmine_app_notifications =
      settings.defaults.merge(
        'issue_note_added' => '0',
        'issue_status_updated' => '1',
        'issue_updated' => '0'
      )
    assert status.send(:should_notify_for_journal?)

    subject = journal_for(issue, details: [['subject', 'Old', 'New']])
    Setting.plugin_redmine_app_notifications =
      settings.defaults.merge(
        'issue_note_added' => '0',
        'issue_status_updated' => '0',
        'issue_assigned_to_updated' => '0',
        'issue_priority_updated' => '0',
        'issue_updated' => '1'
      )
    assert subject.send(:should_notify_for_journal?)

    Setting.plugin_redmine_app_notifications =
      settings.defaults.merge(
        'issue_note_added' => '0',
        'issue_status_updated' => '0',
        'issue_assigned_to_updated' => '0',
        'issue_priority_updated' => '0',
        'issue_updated' => '0'
      )
    assert_not subject.send(:should_notify_for_journal?)
  end

  def test_app_notification_enabled_defaults_to_true
    user = User.find(2)
    others = (user.pref.others || {}).dup
    others.delete('app_notifications')
    others.delete(:app_notifications)
    user.pref.others = others
    user.pref.save!
    assert user.reload.app_notification_enabled?

    user.pref[:app_notifications] = false
    user.pref.save!
    assert_not user.reload.app_notification_enabled?

    user.pref[:app_notifications] = true
    user.pref.save!
    assert user.reload.app_notification_enabled?
  end

  private

  def journal_for(issue, notes: nil, details: [])
    journal = Journal.new(journalized: issue, user: @author, notes: notes)
    details.each do |prop_key, old_value, value|
      journal.details.build(
        property: 'attr',
        prop_key: prop_key,
        old_value: old_value,
        value: value
      )
    end
    journal
  end
end
