# Skill: Observability

Code that can't be observed can't be operated. Every feature ships with the
logging, metrics, and error handling needed to debug it in production.

## Logging
- **Structured** logs (key/value or JSON), not string soup. Include a
  correlation/request id so one request can be traced across layers.
- Log at the right level: `error` (action needed), `warn` (recoverable),
  `info` (lifecycle/business events), `debug` (dev only — off in prod).
- **Never log secrets or PII** — no tokens, passwords, full card/SSN, raw auth
  headers. Mask them.
- Log the *cause* on failure (message + context), not just "error occurred".

## Errors
- Fail loudly at the boundary; don't swallow exceptions. A bare `catch {}` that
  hides the error is a defect.
- Return actionable errors to callers (correct status code + safe message);
  keep stack traces server-side.

## Metrics (new endpoints / jobs)
- Emit count + latency + error-rate where the project already has metrics.
- Health/readiness still pass after the change.

## Rules
- New endpoint or background job → it logs start/finish and failures with context.
- No `console.log` / `print` debugging left in committed code (see `debug-method.md`).
- Reuse the project's existing logger/metrics — don't introduce a new framework.
