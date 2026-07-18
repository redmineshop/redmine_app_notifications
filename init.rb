# frozen_string_literal: true

require 'redmine'

require_relative 'lib/redmine_app_notifications/version'
require_relative 'lib/redmine_app_notifications/settings'
require_relative 'lib/redmine_app_notifications/hooks'
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
         label = I18n.t('redmine_app_notifications.menu_caption')
         count = AppNotification.unread_count_for(User.current)
         count.positive? ? "#{label} (#{count})" : label
       },
       html: { class: 'app-notifications-bell' },
       after: :my_page,
       if: proc { User.current.logged? }
end

unless User.ancestors.include?(RedmineAppNotifications::UserPatch)
  User.prepend(RedmineAppNotifications::UserPatch)
end

unless Issue.ancestors.include?(RedmineAppNotifications::IssuePatch)
  Issue.prepend(RedmineAppNotifications::IssuePatch)
end

unless Journal.ancestors.include?(RedmineAppNotifications::JournalPatch)
  Journal.prepend(RedmineAppNotifications::JournalPatch)
end

unless MyController.ancestors.include?(RedmineAppNotifications::MyControllerPatch)
  MyController.prepend(RedmineAppNotifications::MyControllerPatch)
end
