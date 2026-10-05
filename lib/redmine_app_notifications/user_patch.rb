# frozen_string_literal: true

module RedmineAppNotifications
  module UserPatch
    def app_notification_enabled?
      others = pref.others || {}
      if others.key?('app_notifications')
        value = others['app_notifications']
      elsif others.key?(:app_notifications)
        value = others[:app_notifications]
      else
        return true
      end

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
