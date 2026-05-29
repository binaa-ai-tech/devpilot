# Commit Message Convention

This project uses **Conventional Commits 1.0** enforced by commitlint on every
`git commit`. Non-conforming messages are rejected at the pre-commit hook.

---

## Format

```
<type>(<scope>): <short description>

[optional body]

[optional footer(s)]
```

- **type** — what kind of change (see table below).
- **scope** — which part of the project is affected (see allowed scopes).
- **short description** — imperative, present tense, lowercase, no period, ≤ 72 chars.
- **body** — optional, free-form, wraps at 100 chars.
- **footer** — `BREAKING CHANGE:`, `Closes #123`, co-author lines, etc.

---

## Types

| Type       | When to use                                                   |
| ---------- | ------------------------------------------------------------- |
| `feat`     | A new user-facing feature                                     |
| `fix`      | A bug fix                                                     |
| `chore`    | Build process, tooling, dependency bumps — no production code |
| `refactor` | Code restructuring with no behaviour change                   |
| `docs`     | Documentation only                                            |
| `test`     | Adding or fixing tests                                        |
| `style`    | Formatting, whitespace — no logic change                      |
| `perf`     | Performance improvement                                       |
| `ci`       | CI/CD pipeline changes                                        |
| `revert`   | Reverts a previous commit                                     |

---

## Allowed Scopes

Scopes are project-defined. Add your project's domain scopes to `.commitlintrc.json`.

Common infrastructure scopes included by default:

| Scope    | Covers                                     |
| -------- | ------------------------------------------ |
| `api`    | Backend endpoints, middleware              |
| `web`    | Frontend web app                           |
| `mobile` | Mobile app                                 |
| `admin`  | Admin portal                               |
| `shared` | Shared libraries                           |
| `auth`   | Authentication, sessions, permissions      |
| `db`     | Migrations, schema changes                 |
| `infra`  | Infrastructure, cloud config               |
| `ci`     | GitHub Actions workflows                   |
| `git`    | Branch strategy, hooks, commit tooling     |

Add your domain-specific scopes (e.g. `payments`, `listings`, `search`) in `.commitlintrc.json`.

---

## Examples

```
feat(auth): add OTP retry limit with 5-minute lockout

fix(api): prevent null reference in search endpoint

chore(shared): bump angular to 21.0.0

refactor(web): replace BehaviorSubject with signal in user store

test(db): add integration tests for migration rollback

docs(git): add branch naming and commit convention guides

ci(api): replace --no-build with --no-restore in dotnet test step

feat(payments): implement invoice generation

BREAKING CHANGE: UserDto shape updated — field `name` renamed to `fullName`
```

---

## Breaking Changes

Append `BREAKING CHANGE: <explanation>` in the footer for any commit that
changes a public API contract (DTO shape, endpoint signature, DB schema).
This triggers a major version bump in the release.

---

## References

- [Conventional Commits spec](https://www.conventionalcommits.org/)
- [`.commitlintrc.json`](../.commitlintrc.json)
