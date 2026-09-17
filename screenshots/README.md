# Screenshots — Redmine App Notifications

Captured by the plugin quality harness (Playwright) against demo Redmine.

Refresh (RedmineShop monorepo, not this public plugin repo):

```bash
./demo/scripts/run-plugin-e2e.sh
```

Output:

- `admin-plugins.png` — Administration → Plugins row with Configure
- `plugin-settings.png` — per-event toggles (Redmine tabular settings)
- `top-menu.png` — Notifications entry with unread count
- `notifications-feed.png` — unread feed before Mark as read

This harness covers the in-app feed UI. Email fallback cron is **not** in the Playwright path.
