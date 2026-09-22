# Screenshots — Redmine App Notifications

Captured by Playwright against demo Redmine.

Refresh is **private-monorepo only** (`redmineshop/redmineshop` harness). A public clone of this plugin cannot run that job.

Output:

- `top-menu.png` — logged-in project page; Notifications entry with unread count in the top menu
- `notifications-dropdown.png` — notification page with three unread rows (issue report, note, assignment). The UI is a page, not a dropdown.
- `notifications-feed.png` — same image as `notifications-dropdown.png` (older README path)
- `plugin-settings.png` — full settings page (event checkboxes). `settings.png` is the same image.
- `admin-plugins.png` — Administration → Plugins page

This harness covers the in-app feed UI. Email fallback cron is **not** in the Playwright path.
