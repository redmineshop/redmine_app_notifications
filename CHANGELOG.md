# Changelog — Redmine App Notifications

All notable changes to this plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Public CI boots official Redmine 7.0.1, installs this plugin, runs its migrations, and runs the MiniTest suite on SQLite. Ruby syntax stays a separate job.
- MiniTest for issue create, note, status, assignee, priority, and other updates; per-user opt-out; unread count; mark one and mark all read; private issues, private projects, and private notes; the email fallback rake task.

### Fixed

- The feed, unread count, and mark-all action skip issues the current user cannot see.
- Private notes are not created, listed, or emailed for users who cannot view them.
- Mark as read returns 404 for a missing, non-numeric, or invisible id, and 403 for another user's row. GET does not mark rows read.
- Feed links escape the issue subject and note. The top-menu caption is the localized label plus the unread count.

### Changed

- Compatibility table lists Redmine 7.0.1 as verified on SQLite. Redmine 5.0, 5.1, and 6.x stay declared and were not booted.

## [1.0.0] — 2026-07-18

First community release via RedmineShop.

### Added

- Bell icon in top menu with unread count
- Persisted in-app notification feed (issue create/update events)
- Mark individual or all notifications as read (owner-only)
- Admin plugin settings for event toggles and email fallback
- Optional cron rake task `redmine:app_notifications:email_fallback`
- Per-user preference under My account
- `up` / `down` migration for `app_notifications`
- English and Vietnamese i18n
- Plugin unit + functional tests

### Fixed

- Settings Configure page 404 caused by missing settings partial
- Settings UI: event toggles were invisible (`label.floating` CSS); restored Redmine `fieldset.box.tabular` layout
- Event toggles now persist off state via hidden `0` fields; journal hooks respect each event independently

### Changed

- Settings copy: flat independent event labels; email help split into admin + advanced cron note
- Top menu uses i18n “Notifications” caption with unread count (no emoji)
- Notifications feed uses Redmine `table.list` / contextual links instead of inline styles


[1.0.0]: https://github.com/redmineshop/redmine_app_notifications/releases/tag/v1.0.0
