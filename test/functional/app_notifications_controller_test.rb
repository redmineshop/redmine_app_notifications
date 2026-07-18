# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AppNotificationsControllerTest < Redmine::ControllerTest
  fixtures :projects, :users, :roles, :members, :member_roles, :issues,
           :trackers, :projects_trackers, :issue_statuses, :enumerations,
           :enabled_modules

  def setup
    @user = User.find(2)
    @other = User.find(3)
    AppNotification.delete_all
    @notification = AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: @user.id,
      viewed: false
    )
  end

  def test_index_requires_login
    get :index
    assert_response :redirect
  end

  def test_index_shows_own_notifications
    @request.session[:user_id] = @user.id
    get :index
    assert_response :success
    assert_select 'h2', /Notifications|Thông báo/
    assert_select 'table.list.app-notifications'
    assert_select 'tr.unread', minimum: 1
  end


  def test_mark_read_forbidden_for_other_user
    @request.session[:user_id] = @other.id
    post :mark_read, params: { id: @notification.id }
    assert_response :forbidden
    assert_equal false, @notification.reload.viewed?
  end

  def test_mark_read_own_notification
    @request.session[:user_id] = @user.id
    post :mark_read, params: { id: @notification.id }
    assert_redirected_to '/app_notifications'
    assert @notification.reload.viewed?
  end

  def test_mark_all_read
    @request.session[:user_id] = @user.id
    post :mark_all_read
    assert_redirected_to '/app_notifications'
    assert_equal 0, AppNotification.for_user(@user).unread.count
  end
end
