# Threat Modeling — security by design

Load this **before designing a feature that touches auth, money, personal data, file
uploads, external input, or a new trust boundary.** `security-scan` checks the diff *after*
the fact; threat modeling stops the flaw being designed in.

## The four questions (lightweight STRIDE)
1. **What are we building?** Sketch the data flow: entry points, the data that moves,
   where it's stored, and every **trust boundary** it crosses (client→server, service→service,
   app→DB, your code→third party).
2. **What can go wrong?** Walk STRIDE at each boundary:
   **S**poofing (who are you?), **T**ampering (can input/data be altered?),
   **R**epudiation (can we prove who did it?), **I**nformation disclosure (what leaks?),
   **D**enial of service (what exhausts a resource?), **E**levation of privilege (can a user act as admin?).
3. **What do we do about it?** A mitigation per credible threat — authn/authz at the boundary,
   input validation, encryption, rate limits, least privilege, audit logging.
4. **Did we cover it?** A test or review check per mitigation.

## Defaults to assume
- **Never trust input** — validate and encode at every boundary (see `api-design`).
- **Least privilege** everywhere — tokens, DB users, service roles.
- **Deny by default**; allow explicitly.
- **Don't roll your own crypto/auth** — use vetted libraries.

## Ship-with
- [ ] Trust boundaries identified; each has authn + authz.
- [ ] Untrusted input validated/encoded; no injection paths (SQL, command, XSS, SSRF, path).
- [ ] Secrets handled per `secrets-management`; sensitive data per `data-privacy`.
- [ ] Abuse cases captured as tests; high-risk threats noted in the plan/ADR.
