# Redmine App Notifications

**Free, open source. Download the official package at [redmineshop.com/products/redmine-app-notifications](https://redmineshop.com/products/redmine-app-notifications).**

In-app notification bell for Redmine — issue activity appears in a top-menu feed so users can catch up without living in email.

## Features

- **Notifications** entry in the Redmine top menu with unread count
- In-app feed for issue create / update / note / status / assignee / priority (configurable)
- Mark individual or all notifications as read
- Per-user toggle under **My account**
- Optional email fallback via cron rake task (admin setting)
- Admin settings use standard Redmine tabular forms
- Supports Redmine 5.0.x, 5.1.x, and 6.x
- No Faye or other external realtime services required


## Compatibility

| Redmine | Ruby | Database | Status |
|---------|------|----------|--------|
| 6.x     | 3.2+ | MySQL 8 | Primary QA |
| 5.1.x   | 3.1+ | MySQL 8 | Targeted |
| 5.0.x   | 3.0+ | MySQL 8 | Targeted |

## Installation

**Estimated time: 10 minutes.**

### 1. Download

Get the official package (SHA256 checksum included) at:
**[redmineshop.com/products/redmine-app-notifications](https://redmineshop.com/products/redmine-app-notifications)**

### 2. Extract

```bash
# From your Redmine root directory
cd plugins
tar -xzf redmine_app_notifications-1.0.0.tar.gz
```

### 3. Run migration

```bash
# From Redmine root
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

### 4. Restart Redmine

```bash
# Example for systemd
sudo systemctl restart redmine

# Example for Docker
docker compose restart redmine
```

### 5. Enable per user

Users can enable or disable in-app notifications under **My account** (preferences).

## Uninstall

```bash
bundle exec rake redmine:plugins:migrate NAME=redmine_app_notifications VERSION=0 RAILS_ENV=production
# Then remove the plugin directory from plugins/
```

## Configuration

In **Administration → Plugins → Redmine App Notifications → Configure**:

- **Notification events** — enable/disable in-app notifications per event:
  - Issue added
  - Issue updated (other changes)
  - Issue note added
  - Issue status updated
  - Assignee updated
  - Priority updated
- **Enable email fallback** — when on, run periodically:

```bash
bundle exec rake redmine:app_notifications:email_fallback RAILS_ENV=production
```

This emails unread in-app items older than 24 hours.

## Community support

- [Open an issue on GitHub](https://github.com/redmineshop/redmine_app_notifications/issues)
- [Product page](https://redmineshop.com/products/redmine-app-notifications)

## License

MIT License. See [LICENSE](LICENSE) file.

Originally based on [MichalVanzura/redmine_app_notifications](https://github.com/MichalVanzura/redmine_app_notifications), updated for Redmine 5.x/6.x and maintained by RedmineShop.
