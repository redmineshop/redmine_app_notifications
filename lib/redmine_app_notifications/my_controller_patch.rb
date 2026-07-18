# frozen_string_literal: true

module RedmineAppNotifications
  module MyControllerPatch
    def account
      if mutating_account_request? && params[:pref]
        User.current.pref[:app_notifications] = params[:pref][:app_notifications].to_s == '1'
        User.current.pref.save
      end
      super
    end

    private

    def mutating_account_request?
      request.post? || request.put? || request.patch?
    end
  end
end
