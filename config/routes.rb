# frozen_string_literal: true

get 'app_notifications', to: 'app_notifications#index', as: :app_notifications
post 'app_notifications/mark_all_read', to: 'app_notifications#mark_all_read', as: :app_notifications_mark_all_read
post 'app_notifications/:id/mark_read', to: 'app_notifications#mark_read', as: :app_notification_mark_read
