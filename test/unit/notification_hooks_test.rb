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

  def test_issue_create_writes_one_row_per_recipient
    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Once')
    counts = AppNotification.where(issue_id: issue.id).group(:recipient_id).count
    assert counts.values.all? { |count| count == 1 }, counts.inspect
    assert_includes counts.keys, @recipient.id
  end

  def test_status_change_notifies_when_the_event_is_on
    issue = fresh_issue('Status on')
    change_status(issue, 2)
    assert_notified(@recipient, issue)
  end

  def test_status_change_does_not_fall_through_to_issue_updated
    issue = fresh_issue('Status off')
    disable_events('issue_status_updated', keep_updated: true)
    change_status(issue, 2)
    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_assignee_change_notifies_when_the_event_is_on
    issue = fresh_issue('Assign on')
    change_assignee(issue, @recipient.id)
    assert_notified(@recipient, issue)
  end

  def test_assignee_change_does_not_fall_through_to_issue_updated
    issue = fresh_issue('Assign off')
    disable_events('issue_assigned_to_updated', keep_updated: true)
    change_assignee(issue, @recipient.id)
    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_priority_change_notifies_when_the_event_is_on
    issue = fresh_issue('Priority on')
    change_priority(issue)
    assert_notified(@recipient, issue)
  end

  def test_priority_change_does_not_fall_through_to_issue_updated
    issue = fresh_issue('Priority off')
    disable_events('issue_priority_updated', keep_updated: true)
    change_priority(issue)
    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_other_update_notifies_only_when_issue_updated_is_on
    issue = fresh_issue('Subject on')
    disable_events(
      'issue_note_added',
      'issue_status_updated',
      'issue_assigned_to_updated',
      'issue_priority_updated',
      keep_updated: true
    )
    change_subject(issue, 'Subject changed')
    assert_notified(@recipient, issue)

    AppNotification.delete_all
    disable_events('issue_updated')
    change_subject(issue, 'Subject changed again')
    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_journal_note_skips_users_who_disabled_the_preference
    @recipient.pref[:app_notifications] = false
    @recipient.pref.save!
    issue = fresh_issue('Pref off note')
    issue.init_journal(@author, 'Please review')
    assert issue.save, issue.errors.full_messages.join(', ')
    assert_not_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), @recipient.id
  end

  def test_private_project_does_not_notify_a_non_member
    issue = Issue.generate!(project_id: 2, author: @author, subject: 'Members only')
    assert_not issue.visible?(@recipient), 'fixture user 3 should not see the private project'
    assert_not_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), @recipient.id
  end

  def test_private_issue_does_not_notify_a_user_who_cannot_see_it
    issue = Issue.generate!(
      project_id: 1,
      author: @author,
      subject: 'Secret issue',
      is_private: true
    )
    assert_not issue.visible?(@recipient), 'developer visibility is default, so a private issue stays hidden'
    assert_not_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), @recipient.id
  end

  def test_delivery_skips_a_listed_recipient_who_cannot_see_the_issue
    issue = Issue.generate!(project_id: 1, author: @author, subject: 'Hidden after save')
    issue.update_column(:is_private, true)
    issue.reload
    AppNotification.delete_all
    assert_not issue.visible?(@recipient)

    RedmineAppNotifications::Delivery.deliver(
      issue: issue,
      author_id: @author.id,
      journal: nil,
      recipients: [@recipient]
    )

    assert_equal 0, AppNotification.where(issue_id: issue.id).count
  end

  def test_private_note_does_not_notify_a_user_who_cannot_view_private_notes
    issue = fresh_issue('Private note')
    issue.init_journal(@author, 'secret note body')
    issue.private_notes = true
    assert issue.save, issue.errors.full_messages.join(', ')
    assert_not User.find(@recipient.id).allowed_to?(:view_private_notes, issue.project)
    assert_not_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), @recipient.id
  end

  def test_delivery_skips_private_notes_for_a_listed_recipient
    issue = fresh_issue('Forced private note')
    journal = Journal.new(
      journalized: issue,
      user: @author,
      notes: 'secret note body',
      private_notes: true
    )
    journal.notify = false
    assert journal.save, journal.errors.full_messages.join(', ')
    AppNotification.delete_all

    RedmineAppNotifications::Delivery.deliver(
      issue: issue,
      author_id: @author.id,
      journal: journal,
      recipients: [@recipient]
    )

    assert_equal 0, AppNotification.where(issue_id: issue.id).count
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

  def fresh_issue(subject, **attrs)
    issue = Issue.generate!({ project_id: 1, author: @author, subject: subject }.merge(attrs))
    AppNotification.delete_all
    issue
  end

  def disable_events(*keys, keep_updated: false)
    settings = RedmineAppNotifications::Settings.defaults
    keys.each { |key| settings[key] = '0' }
    settings['issue_updated'] = keep_updated ? '1' : '0'
    Setting.plugin_redmine_app_notifications = settings
  end

  def change_status(issue, status_id)
    issue.init_journal(@author)
    issue.status_id = status_id
    assert issue.save, issue.errors.full_messages.join(', ')
  end

  def change_assignee(issue, user_id)
    issue.init_journal(@author)
    issue.assigned_to_id = user_id
    assert issue.save, issue.errors.full_messages.join(', ')
  end

  def change_priority(issue)
    priority = IssuePriority.where.not(id: issue.priority_id).first
    assert priority, 'expected another issue priority in fixtures'
    issue.init_journal(@author)
    issue.priority_id = priority.id
    assert issue.save, issue.errors.full_messages.join(', ')
  end

  def change_subject(issue, subject)
    issue.init_journal(@author)
    issue.subject = subject
    assert issue.save, issue.errors.full_messages.join(', ')
  end

  def assert_notified(user, issue)
    assert_includes AppNotification.where(issue_id: issue.id).pluck(:recipient_id), user.id
  end

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
