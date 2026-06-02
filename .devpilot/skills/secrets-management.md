# Secrets Management — credentials never live in code

Load this **before handling any credential, token, API key, connection string, or `.env`.**
Expands `core-rules` #4. A leaked secret is a breach, and git remembers forever.

## Rules
- **Never commit secrets.** Not in code, config, tests, fixtures, or comments. `.env*` is
  gitignored; commit a redacted `.env.example` with keys and dummy values only.
- **Read from the environment / a secret manager** (Vault, AWS/GCP Secrets Manager, KMS, CI
  secret store) — never hardcode. Code references a *name*, never a *value*.
- **Least privilege & scoped** — a token does one job; separate secrets per environment.
- **No secrets in logs or error messages** (see `observability`); redact before logging.
- **Rotate** on a schedule and immediately on suspected exposure; design so rotation is a
  config change, not a code change.

## If a secret leaks
1. **Rotate/revoke it first** — assume it's compromised the moment it hit a shared place.
2. Purge it from history (filter-repo / BFG) and force-push; rewriting alone isn't enough —
   it was already cloneable, so step 1 is what actually protects you.
3. Note it in `incident-postmortem` if it reached production or a public repo.

## Ship-with
- [ ] No secret values in the diff (grep for keys, `BEGIN PRIVATE KEY`, long base64/hex).
- [ ] New secret added to `.env.example` (redacted) + the deploy/secret store, documented.
- [ ] Code reads via env/secret manager; nothing sensitive logged.
