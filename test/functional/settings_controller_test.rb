# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class AppNotificationsSettingsControllerTest < Redmine::ControllerTest
  tests SettingsController

  fixtures :users

  def setup
    @request.session[:user_id] = 1 # admin
  end

  def test_plugin_settings_renders_event_checkboxes
    get :plugin, params: { id: 'redmine_app_notifications' }
    assert_response :success

    assert_select 'fieldset.box.tabular', minimum: 2
    RedmineAppNotifications::Settings::EVENT_KEYS.each do |key|
      assert_select "label[for=?]", "settings_#{key}"
      assert_select "input[type=checkbox][name=?][value=1]", "settings[#{key}]"
      assert_select "input[type=hidden][name=?][value=0]", "settings[#{key}]"
    end
    assert_select "input[type=checkbox][name=?][value=1]", 'settings[enable_email_fallback]'
    # Labels must not wrap checkboxes (Redmine tabular layout)
    assert_select 'fieldset.box.tabular label input[type=checkbox]', count: 0
  end


  def test_plugin_settings_save_disables_event
    post :plugin, params: {
      id: 'redmine_app_notifications',
      settings: RedmineAppNotifications::Settings.defaults.merge('issue_added' => '0')
    }
    assert_redirected_to '/settings/plugin/redmine_app_notifications'
    assert_equal '0', Setting.plugin_redmine_app_notifications['issue_added']
    assert_not RedmineAppNotifications::Settings.enabled?('issue_added')
  ensure
    Setting.plugin_redmine_app_notifications = RedmineAppNotifications::Settings.defaults
  end
end
