# Screenshots — Redmine App Notifications

Captured by Playwright against demo Redmine.

Refresh is **private-monorepo only** (`redmineshop/redmineshop` harness). A public clone of this plugin cannot run that job.

Output:

- `admin-plugins.png` — Administration → Plugins row with Configure
- `plugin-settings.png` — per-event toggles (Redmine tabular settings)
- `top-menu.png` — Notifications entry with unread count
- `notifications-feed.png` — unread feed before Mark as read

This harness covers the in-app feed UI. Email fallback cron is **not** in the Playwright path.
