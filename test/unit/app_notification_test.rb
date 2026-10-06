# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AppNotificationTest < ActiveSupport::TestCase
  fixtures :projects, :users, :issues, :trackers, :projects_trackers,
           :issue_statuses, :enumerations, :enabled_modules

  def test_unread_count_for_logged_user
    user = User.find(2)
    AppNotification.delete_all
    AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: user.id,
      viewed: false
    )
    assert_equal 1, AppNotification.unread_count_for(user)
  end

  def test_mark_viewed
    n = AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: User.find(2).id,
      viewed: false
    )
    n.mark_viewed!
    assert n.reload.viewed?
  end

  def test_message_text_for_new_issue
    n = AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: User.find(2).id,
      viewed: false
    )
    assert_includes n.message_text, "##{Issue.first.id}"
    assert_not n.message_text.html_safe?
  end

  def test_unread_count_ignores_other_users_viewed_rows_and_hidden_issues
    user = User.find(3)
    visible = Issue.find(1)
    hidden = Issue.find(4)
    assert visible.visible?(user)
    assert_not hidden.visible?(user)
    AppNotification.delete_all
    AppNotification.create!(issue_id: visible.id, author_id: 1, recipient_id: user.id, viewed: false)
    AppNotification.create!(issue_id: visible.id, author_id: 1, recipient_id: user.id, viewed: true)
    AppNotification.create!(issue_id: hidden.id, author_id: 1, recipient_id: user.id, viewed: false)
    AppNotification.create!(issue_id: visible.id, author_id: 1, recipient_id: 2, viewed: false)

    assert_equal 1, AppNotification.unread_count_for(user)
  end

  def test_visible_to_scope_keeps_the_recipient_and_drops_hidden_issues
    user = User.find(3)
    other = User.find(2)
    AppNotification.delete_all
    mine = AppNotification.create!(issue_id: 1, author_id: 1, recipient_id: user.id, viewed: false)
    AppNotification.create!(issue_id: 4, author_id: 1, recipient_id: user.id, viewed: false)
    AppNotification.create!(issue_id: 1, author_id: 1, recipient_id: other.id, viewed: false)

    assert_equal [mine.id], AppNotification.for_user(user).visible_to(user).pluck(:id)
    assert AppNotification.find(mine.id).visible_to?(user)
    hidden = AppNotification.find_by!(issue_id: 4, recipient_id: user.id)
    assert_not hidden.visible_to?(user)
  end

  def test_private_note_rows_are_hidden_from_users_who_cannot_read_them
    reader = User.find(2)
    outsider = User.find(3)
    issue = Issue.find(1)
    journal = Journal.new(
      journalized: issue,
      user: reader,
      notes: 'secret note body',
      private_notes: true
    )
    journal.notify = false
    assert journal.save, journal.errors.full_messages.join(', ')
    AppNotification.delete_all
    row = AppNotification.create!(
      issue_id: issue.id,
      journal_id: journal.id,
      author_id: reader.id,
      recipient_id: outsider.id,
      viewed: false
    )
    own = AppNotification.create!(
      issue_id: issue.id,
      journal_id: journal.id,
      author_id: reader.id,
      recipient_id: reader.id,
      viewed: false
    )

    assert_not AppNotification.visible_to(outsider).exists?(id: row.id)
    assert_not row.visible_to?(outsider)
    assert AppNotification.visible_to(reader).exists?(id: own.id)
    assert own.visible_to?(reader)
  end

  def test_record_drops_primary_key_and_unknown_attributes
    row = AppNotification.record!(
      id: 424_242,
      issue_id: Issue.first.id,
      author_id: 1,
      recipient_id: 2,
      viewed: false,
      admin: true,
      'not_a_column' => 'x'
    )
    assert_not_equal 424_242, row.id
    assert_equal 2, row.recipient_id
    assert_equal false, row.viewed?
  end
end
