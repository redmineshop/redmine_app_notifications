# Changelog — Redmine App Notifications

All notable changes to this plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Mark as read returns 404 for a missing or non-numeric id. Another user's notification still returns 403 and is left unread.
- Email fallback sends one `text/plain` digest per recipient, skips issues that recipient can no longer see, and ignores mail headers that contain line breaks. One recipient's delivery error does not stop the rest of the run.
- My account saves the in-app notification checkbox after a successful account update, including when the box is unchecked.

### Added

- MiniTest for the email fallback rake behavior, issue and journal notification hooks, and the My account preference toggle.

### Changed

- Community install is **GitHub-first** (`git clone https://github.com/redmineshop/redmine_app_notifications.git`). Email-funnel packages are no longer the documented download path.
- README: Last maintained date, screenshots, and untested compatibility cells. Install path is GitHub clone.

### Added

- Plugin quality harness on the RedmineShop demo stack: Playwright E2E for the Configure page, top-menu unread count, in-app feed, and mark as read, plus README screenshots.

### Notes

- Email fallback cron is **not** in this E2E. Do not treat the harness as a Redmine 5.1 / 6.x matrix.

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
