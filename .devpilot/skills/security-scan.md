# Skill: Security Scan

Run this checklist before every commit and during code review.

## All code
- [ ] No hardcoded secrets, tokens, passwords, or API keys anywhere in code
- [ ] No environment-specific URLs or credentials committed
- [ ] Sensitive data is not logged to console or application logs

## Backend (.NET / SQL)
- [ ] All SQL is parameterized — no string concatenation, `sp_executesql` for dynamic SQL
- [ ] All user input is validated before use (data annotations, FluentValidation, or explicit guards)
- [ ] Every endpoint that touches user data has an authorization check (`[Authorize]`, role/policy checks)
- [ ] Error responses return generic messages — no stack traces, no internal type names, no DB errors exposed to clients
- [ ] File uploads: validate extension whitelist, MIME type, and max file size
- [ ] No direct object reference without ownership check (e.g. `GET /api/orders/{id}` → verify order belongs to the calling user)
- [ ] CORS policy is not wildcard `*` in non-development environments

## Frontend (Angular / React)
- [ ] No `innerHTML` or `[innerHTML]` binding with unsanitized content — Angular: use `DomSanitizer.bypassSecurityTrustHtml` only when truly safe; React: never use `dangerouslySetInnerHTML` with user-provided data
- [ ] Auth tokens stored in httpOnly cookies or memory — never in `localStorage`
- [ ] API calls include auth headers, not URL query params containing tokens
- [ ] No hardcoded API keys, secrets, or internal URLs in frontend bundle

## Severity
- 🔴 **CRITICAL** (blocks PR): SQL injection risk, auth bypass, secret in code, XSS via unsanitized HTML
- 🟡 **WARNING** (noted in review): missing input validation, overly permissive CORS, token in localStorage
