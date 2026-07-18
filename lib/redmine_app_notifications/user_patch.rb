# frozen_string_literal: true

module RedmineAppNotifications
  module UserPatch
    def app_notification_enabled?
      value = pref[:app_notifications]
      return true if value.nil?

      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
