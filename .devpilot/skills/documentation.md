# Documentation — docs are a deliverable, not an afterthought

Load this **when shipping a feature/module, making a significant decision, or adding an
operational procedure.** Undocumented systems force tribal knowledge and slow everyone down.
Docs are part of `definition-of-done`.

## Write the right doc for the job
- **README** (per repo/service) — what it is, how to run it locally, configuration, how to test.
  The onboarding contract: a new engineer is productive from the README alone.
- **ADR** (`docs/adrs/`) — for any significant or hard-to-reverse decision. Capture **context,
  the decision, alternatives considered, and consequences**. Short and immutable; supersede, don't edit.
- **Runbook** — for anything on-call/ops touches: how to deploy, roll back, rotate a secret,
  respond to a common alert. Steps a tired engineer can follow at 3am.
- **API docs** — the contract (OpenAPI/typed DTOs), owned with the code (see `api-design`).

## Principles
- **Keep docs next to the code** and update them in the same PR as the change — stale docs are
  worse than none. Link from the PR/ticket, don't paste (see `core-rules` #11).
- **Explain the *why*** — rationale and trade-offs outlive the implementation details.
- **Concise and skimmable** — headings, lists, examples over prose walls.

## Ship-with
- [ ] README/config updated for new setup or behavior.
- [ ] Significant decisions captured in an ADR; ops procedures in a runbook.
- [ ] Docs changed in the same PR as the code; nothing stale left behind.
