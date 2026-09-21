# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class MyAccountPreferenceTest < Redmine::ControllerTest
  tests MyController

  fixtures :users, :email_addresses, :user_preferences

  def setup
    @user = User.find(2)
    @request.session[:user_id] = @user.id
    @user.pref[:app_notifications] = true
    @user.pref.save!
  end

  def test_account_page_renders_the_preference_checkbox
    get :account
    assert_response :success
    assert_select 'input[type=hidden][name=?][value=0]', 'pref[app_notifications]'
    assert_select 'input[type=checkbox][name=?][value=1]', 'pref[app_notifications]'
  end

  def test_put_disables_and_enables_in_app_notifications
    put_account('0')
    assert_redirected_to '/my/account'
    assert_not User.find(@user.id).app_notification_enabled?

    put_account('1')
    assert_redirected_to '/my/account'
    assert User.find(@user.id).app_notification_enabled?
  end

  def test_get_does_not_change_the_preference
    get :account
    assert_response :success
    assert User.find(@user.id).app_notification_enabled?
  end

  def test_put_without_the_preference_key_leaves_it_unchanged
    put :account, params: {
      user: account_user_params,
      pref: { hide_mail: '0' }
    }
    assert_redirected_to '/my/account'
    assert User.find(@user.id).app_notification_enabled?
  end

  def test_invalid_account_update_does_not_change_the_preference
    put :account, params: {
      user: account_user_params.merge(mail: 'not-an-email'),
      pref: { app_notifications: '0' }
    }
    assert_response :success
    assert User.find(@user.id).app_notification_enabled?
  end

  private

  def put_account(flag)
    put :account, params: {
      user: account_user_params,
      pref: { hide_mail: '0', app_notifications: flag }
    }
  end

  def account_user_params
    {
      firstname: @user.firstname,
      lastname: @user.lastname,
      mail: @user.mail,
      language: @user.language
    }
  end
end
