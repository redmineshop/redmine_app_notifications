# frozen_string_literal: true

module RedmineAppNotifications
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_my_account_preferences,
              partial: 'app_notifications/my_account_preferences'
    render_on :view_layouts_base_html_head,
              partial: 'app_notifications/html_head'
  end
end
