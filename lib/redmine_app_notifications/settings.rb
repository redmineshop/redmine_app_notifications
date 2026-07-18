# frozen_string_literal: true

module RedmineAppNotifications
  module Settings
    EVENT_KEYS = %w[
      issue_added
      issue_updated
      issue_note_added
      issue_status_updated
      issue_assigned_to_updated
      issue_priority_updated
    ].freeze

    module_function

    def defaults
      EVENT_KEYS.index_with { |_k| '1' }.merge(
        'enable_email_fallback' => '0'
      )
    end

    def plugin_settings
      Setting.plugin_redmine_app_notifications || {}
    rescue StandardError
      {}
    end

    def enabled?(key)
      checked?(plugin_settings, key)
    end

    # True when the setting value is explicitly on ('1' / true).
    # Missing keys are treated as off so unchecked boxes persist correctly.
    def checked?(settings_hash, key)
      value = (settings_hash || {})[key.to_s]
      value.to_s == '1' || value == true
    end

    def email_fallback_enabled?
      enabled?('enable_email_fallback')
    end
  end
end

