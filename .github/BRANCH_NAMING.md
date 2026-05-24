# Branch Naming Conventions — Maskan

All branches follow a consistent naming scheme so CI, tooling, and reviewers
can immediately understand the purpose of a branch.

---

## Branch Types

| Branch      | Pattern                           | Purpose                                       | Base branch | Merges into        |
| ----------- | --------------------------------- | --------------------------------------------- | ----------- | ------------------ |
| `main`      | `main`                            | Production — tagged releases only             | —           | —                  |
| `develop`   | `develop`                         | Integration — all finished features land here | —           | `main` via release |
| `feature/*` | `feature/mas-{ticket}-{slug}`     | New feature or enhancement                    | `develop`   | `develop`          |
| `release/*` | `release/{major}.{minor}.{patch}` | Staging / UAT hardening                       | `develop`   | `main` + `develop` |
| `hotfix/*`  | `hotfix/mas-{ticket}-{slug}`      | Emergency production fix                      | `main`      | `main` + `develop` |

---

## Naming Rules

- All lowercase, hyphen-separated words.
- Ticket number is the Jira key in lowercase: `mas-42`, not `MSK-42`.
- Slug: brief imperative description, max 5 words, no spaces.
- No trailing slashes or dots.

---

## Examples

```
feature/mas-12-qdrant-reranking
feature/mas-34-arabic-search-filters
feature/mas-55-whatsapp-otp-fallback

release/1.0.0
release/1.1.0
release/2.0.0

hotfix/mas-99-fix-login-crash
hotfix/mas-102-fix-otp-expiry
```

---

## Creating Branches

Use the helper script for consistent branch creation:

```bash
# Feature
bash scripts/git-flow.sh feature-start 12 qdrant-reranking

# Release
bash scripts/git-flow.sh release-start 1.0.0

# Hotfix
bash scripts/git-flow.sh hotfix-start 99 fix-login-crash
```

See [`scripts/git-flow.sh`](../scripts/git-flow.sh) for full documentation.
