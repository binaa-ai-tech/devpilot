# Commit Message Convention — Maskan

Maskan uses **Conventional Commits 1.0** enforced by commitlint on every
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

| Scope     | Covers                                            |
| --------- | ------------------------------------------------- |
| `rentals` | Short / medium / long-term rental module          |
| `resale`  | Buy / sell apartment module                       |
| `land`    | Government land transfer (تنازل) module           |
| `auth`    | Authentication, OTP, JWT                          |
| `api`     | .NET Web API, endpoints, middleware               |
| `mobile`  | Ionic / Capacitor mobile app                      |
| `web`     | Angular consumer web app                          |
| `admin`   | Admin portal                                      |
| `shared`  | Shared libs: shared-models, shared-ui, api-client |
| `i18n`    | Translations, RTL, language switching             |
| `db`      | EF Core migrations, schema changes                |
| `infra`   | Azure IaC (Bicep/Terraform)                       |
| `ci`      | GitHub Actions workflows                          |
| `git`     | Branch strategy, hooks, commit tooling            |

---

## Examples

```
feat(rentals): add availability calendar to listing detail page

fix(auth): prevent OTP reuse after successful verification

chore(shared): bump jest-preset-angular to 14.2.0

refactor(api): replace IOptions with IOptionsMonitor for Gemini settings

test(land): add integration tests for تنازل installment calculator

docs(git): add branch naming and commit convention guides

ci(api): replace --no-build with --no-restore in dotnet test step

feat(land): implement government contract transfer matching engine

BREAKING CHANGE: WantDto shape updated — field `area` renamed to `areaSqm`
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
