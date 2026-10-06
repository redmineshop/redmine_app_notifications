# frozen_string_literal: true

module AppNotificationsHelper
  # Plain-text title for the feed link. The view passes it to `link_to`,
  # which escapes it. Private notes stay out unless the current user may read them.
  def feed_item_title(notification)
    parts = []
    subject = notification.issue&.subject
    parts << subject.to_s if subject.present?
    notes = notification_notes_for_display(notification)
    parts << notes if notes.present?
    parts.join(' — ')
  end

  def feed_item_link_options(notification)
    title = feed_item_title(notification)
    title.present? ? { title: title } : {}
  end

  def notification_notes_for_display(notification)
    journal = notification.journal
    return '' if journal.nil? || journal.notes.blank?

    issue = notification.issue
    if journal.private_notes?
      return '' unless issue && User.current.allowed_to?(:view_private_notes, issue.project)
    end

    journal.notes.to_s
  end
end
