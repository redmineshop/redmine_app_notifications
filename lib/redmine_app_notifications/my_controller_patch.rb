# frozen_string_literal: true

module RedmineAppNotifications
  module MyControllerPatch
    def account
      super
      persist_app_notification_preference
    end

    private

    # Persist only after Redmine accepts the account update, and only when the
    # form actually submitted the checkbox (hidden 0 + checkbox 1).
    def persist_app_notification_preference
      return unless mutating_account_request?
      return unless response.redirect?

      pref_params = params[:pref]
      return unless pref_params.respond_to?(:key?)
      return unless pref_params.key?('app_notifications')

      User.current.pref[:app_notifications] = pref_params[:app_notifications].to_s == '1'
      User.current.pref.save
    end

    def mutating_account_request?
      request.post? || request.put? || request.patch?
    end
  end
end
