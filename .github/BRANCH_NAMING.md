# Branch Naming Conventions

All branches follow a consistent naming scheme so CI, tooling, and reviewers
can immediately understand the purpose of a branch.

---

## Branch Types

| Branch      | Pattern                               | Purpose                                       | Base branch | Merges into        |
| ----------- | ------------------------------------- | --------------------------------------------- | ----------- | ------------------ |
| `main`      | `main`                                | Production — tagged releases only             | —           | —                  |
| `develop`   | `develop`                             | Integration — all finished features land here | —           | `main` via release |
| `feature/*` | `feature/{PREFIX}-{ticket}-{slug}`    | New feature or enhancement                    | `develop`   | `develop`          |
| `release/*` | `release/{major}.{minor}.{patch}`     | Staging / UAT hardening                       | `develop`   | `main` + `develop` |
| `hotfix/*`  | `hotfix/{PREFIX}-{ticket}-{slug}`     | Emergency production fix                      | `main`      | `main` + `develop` |

---

## Naming Rules

- All lowercase, hyphen-separated words.
- `{PREFIX}` is set in `.aidev/config.sh` → `TICKET_PREFIX` (e.g. `msk`, `key`, `app`).
- `{ticket}` is the Jira ticket number (e.g. `12`, `99`, `101`).
- `{slug}` is a brief imperative description, max 5 words, no spaces.
- No trailing slashes or dots.

---

## Examples

```
feature/key-12-user-search-filters
feature/key-34-price-range-filter
feature/key-55-email-notifications

release/1.0.0
release/1.1.0
release/2.0.0

hotfix/key-99-fix-login-crash
hotfix/key-102-fix-otp-expiry
```

_(Replace `key` with your project's `TICKET_PREFIX` from `.aidev/config.sh`)_

---

## Creating Branches

Use the helper script — it reads `TICKET_PREFIX` from `.aidev/config.sh` automatically:

```bash
# Feature
bash scripts/git-flow.sh feature-start 12 user-search-filters

# Release
bash scripts/git-flow.sh release-start 1.0.0

# Hotfix
bash scripts/git-flow.sh hotfix-start 99 fix-login-crash
```

See [`scripts/git-flow.sh`](../scripts/git-flow.sh) for full documentation.
