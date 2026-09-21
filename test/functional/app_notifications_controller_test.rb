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

  def test_index_hides_other_users_notifications
    AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: @other.id,
      viewed: false
    )
    @request.session[:user_id] = @user.id
    get :index
    assert_response :success
    assert_select 'table.list.app-notifications tbody tr', count: 1
  end

  def test_mark_all_read_does_not_change_other_users_rows
    other = AppNotification.create!(
      issue_id: Issue.first.id,
      author_id: User.find(1).id,
      recipient_id: @other.id,
      viewed: false
    )
    @request.session[:user_id] = @user.id
    post :mark_all_read
    assert_redirected_to '/app_notifications'
    assert @notification.reload.viewed?
    assert_equal false, other.reload.viewed?
  end

  def test_mark_read_missing_id_is_not_found
    @request.session[:user_id] = @user.id
    post :mark_read, params: { id: '99999999' }
    assert_response :not_found
    assert_equal false, @notification.reload.viewed?
  end

  def test_mark_read_rejects_non_numeric_id
    @request.session[:user_id] = @user.id
    post :mark_read, params: { id: '1 OR 1=1' }
    assert_response :not_found
    assert_equal false, @notification.reload.viewed?
  end

  def test_mark_read_routes_are_post_only
    path = "/app_notifications/#{@notification.id}/mark_read"
    assert_routing(
      { method: :post, path: path },
      controller: 'app_notifications', action: 'mark_read', id: @notification.id.to_s
    )
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(path, method: :get)
    end
    assert_routing(
      { method: :post, path: '/app_notifications/mark_all_read' },
      controller: 'app_notifications', action: 'mark_all_read'
    )
  end

  def test_index_renders_post_forms_for_mark_read
    @request.session[:user_id] = @user.id
    get :index
    assert_select "form[action='#{app_notification_mark_read_path(@notification)}'][method=post]"
    assert_select "form[action='#{app_notifications_mark_all_read_path}'][method=post]"
  end

  def test_index_escapes_author_and_project_names
    author = User.find(@notification.author_id)
    project = Issue.find(@notification.issue_id).project
    original_firstname = author.firstname
    original_project_name = project.name
    User.where(id: author.id).update_all(firstname: '<script>alert(1)</script>')
    Project.where(id: project.id).update_all(name: '<img src=x onerror=alert(1)>')

    @request.session[:user_id] = @user.id
    get :index
    assert_response :success
    assert_no_match(/<script>alert\(1\)<\/script>/, response.body)
    assert_no_match(/<img src=x onerror=alert\(1\)>/, response.body)
    assert_match(/&lt;script&gt;alert\(1\)&lt;\/script&gt;/, response.body)
    assert_match(/&lt;img src=x onerror=alert\(1\)&gt;/, response.body)
  ensure
    User.where(id: author.id).update_all(firstname: original_firstname) if author && original_firstname
    Project.where(id: project.id).update_all(name: original_project_name) if project && original_project_name
  end

  def test_mark_read_requires_authenticity_token
    @request.session[:user_id] = @user.id
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    begin
      post :mark_read, params: { id: @notification.id }
    rescue ActionController::InvalidAuthenticityToken
      # Rejected before the action. The row must stay unread either way.
    end
    assert_equal false, @notification.reload.viewed?, 'mark_read changed state without an authenticity token'
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def test_index_includes_authenticity_token_when_forgery_protection_is_on
    @request.session[:user_id] = @user.id
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    get :index
    assert_response :success
    assert_select 'input[name=authenticity_token]', minimum: 1
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
