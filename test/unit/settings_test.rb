# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class RedmineAppNotificationsSettingsTest < ActiveSupport::TestCase
  def test_defaults_enable_all_events
    defaults = RedmineAppNotifications::Settings.defaults
    RedmineAppNotifications::Settings::EVENT_KEYS.each do |key|
      assert_equal '1', defaults[key], "expected default on for #{key}"
    end
    assert_equal '0', defaults['enable_email_fallback']
  end

  def test_checked_reads_hash_values
    assert RedmineAppNotifications::Settings.checked?({ 'issue_added' => '1' }, 'issue_added')
    assert_not RedmineAppNotifications::Settings.checked?({ 'issue_added' => '0' }, 'issue_added')
    assert_not RedmineAppNotifications::Settings.checked?({}, 'issue_added')
  end

  def test_enabled_uses_plugin_setting
    Setting.plugin_redmine_app_notifications = {
      'issue_added' => '0',
      'issue_updated' => '1'
    }
    assert_not RedmineAppNotifications::Settings.enabled?('issue_added')
    assert RedmineAppNotifications::Settings.enabled?('issue_updated')
  ensure
    Setting.plugin_redmine_app_notifications = RedmineAppNotifications::Settings.defaults
  end
end
