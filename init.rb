# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_app_notifications/version'
require_relative 'lib/redmine_app_notifications/settings'
require_relative 'lib/redmine_app_notifications/hooks'
require_relative 'lib/redmine_app_notifications/delivery'
require_relative 'lib/redmine_app_notifications/user_patch'
require_relative 'lib/redmine_app_notifications/issue_patch'
require_relative 'lib/redmine_app_notifications/journal_patch'
require_relative 'lib/redmine_app_notifications/my_controller_patch'

Redmine::Plugin.register :redmine_app_notifications do
  name 'Redmine App Notifications'
  author 'RedmineShop'
  author_url 'https://redmineshop.com'
  description 'In-app notification bell for Redmine — issue updates without email noise.'
  version RedmineAppNotifications::VERSION
  url 'https://redmineshop.com/products/redmine-app-notifications'

  requires_redmine version_or_higher: '5.0'

  settings default: RedmineAppNotifications::Settings.defaults,
           partial: 'settings/redmine_app_notifications'

  menu :top_menu,
       :app_notifications,
       { controller: 'app_notifications', action: 'index' },
       caption: proc {
         label = I18n.t('redmine_app_notifications.menu_caption').to_s
         count =
           begin
             AppNotification.unread_count_for(User.current)
           rescue StandardError
             0
           end
         count = count.to_i
         count.positive? ? "#{label} (#{count})" : label
       },
       html: { class: 'app-notifications-bell' },
       after: :my_page,
       if: proc { User.current.logged? }
end

module RedmineAppNotifications
  def self.apply_patches!
    prepend_once(User, UserPatch)
    prepend_once(Issue, IssuePatch)
    prepend_once(Journal, JournalPatch)
    prepend_once(MyController, MyControllerPatch)
  end

  def self.prepend_once(model, patch)
    return if model.ancestors.include?(patch)

    model.prepend(patch)
  end
end

RedmineAppNotifications.apply_patches!

reloader = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Callbacks
reloader.to_prepare do
  RedmineAppNotifications.apply_patches!
end
