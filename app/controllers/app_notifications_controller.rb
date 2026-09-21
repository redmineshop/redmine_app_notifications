# frozen_string_literal: true

class AppNotificationsController < ApplicationController
  before_action :require_login
  before_action :find_notification, only: %i[mark_read]

  def index
    scope = AppNotification.for_user(User.current).includes(:issue, :author, :journal).recent_first
    @unread_count = scope.unread.count
    @notifications = scope.limit(50)
  end

  def mark_read
    unless @notification.recipient_id == User.current.id
      render_403
      return
    end

    @notification.mark_viewed!
    redirect_to app_notifications_path, notice: l('redmine_app_notifications.marked_read')
  end

  def mark_all_read
    AppNotification.for_user(User.current).unread.update_all(viewed: true)
    redirect_to app_notifications_path, notice: l('redmine_app_notifications.marked_all_read')
  end

  private

  def find_notification
    # Reject non-numeric ids before the query so array or SQL-shaped params cannot reach find.
    id = params[:id].to_s
    unless /\A[1-9]\d*\z/.match?(id)
      render_404
      return
    end

    @notification = AppNotification.find_by(id: id)
    return if @notification

    render_404
  end
end
