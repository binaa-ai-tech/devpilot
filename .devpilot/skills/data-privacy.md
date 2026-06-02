# Data Privacy — handle personal data deliberately

Load this **before storing, processing, logging, or sharing personal or sensitive data**
(names, emails, phone, location, payment, health, government IDs, anything identifying a person).

## Classify, then minimize
- **Classify** the data: public · internal · confidential · personal/PII · sensitive (health,
  payment, biometric). The class sets the controls.
- **Minimize** — collect only what the feature needs, keep it only as long as needed.
  The safest data is the data you never stored.
- **Purpose-bind** — use data only for what it was collected for.

## Controls by class
- **Encrypt** PII/sensitive in transit (TLS) and at rest; pair with `secrets-management` for keys.
- **Access on a need-to-know basis**; log access to sensitive records (audit trail).
- **Don't put PII in logs, URLs, analytics, or error reports** — mask/tokenize (see `observability`).
- **Pseudonymize/anonymize** for analytics and non-prod environments; never copy real PII into dev/test.

## Rights & retention (GDPR/CCPA shape)
- Support **access, correction, and erasure** ("right to be forgotten") — design deletes that
  actually delete (including backups policy, derived data, caches).
- Define **retention** per data type; auto-expire. Capture **consent** where required.
- Cross-border transfer and third-party processors are decisions — record them in an ADR.

## Ship-with
- [ ] Data classified; only necessary fields collected, with a retention rule.
- [ ] PII encrypted in transit + at rest; absent from logs/URLs/analytics.
- [ ] Deletion/export path exists for personal data; no real PII in non-prod.
