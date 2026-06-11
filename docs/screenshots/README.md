# Screenshot Guide

Screenshots are useful for explaining the WebUI, but they must be sanitized
before they are committed.

## Required Views

Capture these views when preparing release documentation:

| File | View | Notes |
|---|---|---|
| `overview.jpg` | Overview dashboard | Hide hostnames, private IPs, and real status details if needed. |
| `data.jpg` | Data/Media page | Use sample files or blurred filenames. |
| `mobile-data.jpg` | Mobile Data/Media page | Use a narrow viewport and sample files. |
| `sources.jpg` | Sources settings | Use fake source IDs, labels, and paths. |
| `telegram.jpg` | Telegram settings | Never show real bot tokens or chat IDs. |
| `telegram-debug.jpg` | Telegram debug | Use a sanitized log excerpt. |
| `general-settings.jpg` | General settings | Show language and web timezone controls. |
| `maintenance.jpg` | Maintenance actions | Avoid real backup names or archive destinations. |
| `network-guardian.jpg` | Network Guardian / emergency AP | Hide SSIDs, passwords, and private IPs. |

## Sanitizing Rules

Before committing screenshots:

- replace real tokens, chat IDs, passwords, hostnames, private IPs, and archive
  targets with example values
- avoid real camera names, household names, or exact locations
- use sample media files where possible
- keep browser chrome out of screenshots unless it helps explain the workflow
- use the current WebUI theme and default layout

## Capture Checklist

Use a desktop viewport and a narrow mobile viewport for views that change
layout significantly:

```text
desktop: 1440x1000
mobile: 390x844
```

If screenshots are generated from a live system, copy only the sanitized image
files into this directory. Do not commit logs, generated preview caches, queue
state, runtime data, or raw browser captures that still contain secrets.

## Documentation Usage

Reference screenshots from Markdown with relative paths, for example:

```markdown
![Data page](screenshots/data.jpg)
```

Do not add broken image links before the sanitized files exist.
