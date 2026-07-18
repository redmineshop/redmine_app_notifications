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
  end
end
