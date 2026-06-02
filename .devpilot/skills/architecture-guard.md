# Skill: Architecture Guardrails

Enforce these patterns. Flag violations in the review doc.

## Backend — Clean Architecture (strictly enforced)

**Layer rule:**
```
HTTP Request → Controller → Service → Repository → Database
```

- **Controller**: HTTP plumbing only. Deserialize input, call one service method, serialize output. Zero business logic.
- **Service**: ALL business logic. Orchestrate repositories. Own transactions. Return domain models or Result types.
- **Repository**: ALL data access. Return domain models. Zero business logic. Zero HTTP concerns.
- **DTO vs Domain model**: DTOs cross the API boundary (in/out of controllers). Domain models live inside the service layer.

### BLOCKER violations
- Business logic in a Controller action method
- `DbContext` or any repository injected directly into a Controller
- Domain model returned directly from a Controller endpoint (must map to DTO first)
- Repository calling another Repository (use a Service to orchestrate)
- `HttpContext` accessed inside a Service or Repository

### Patterns to apply
- **Result pattern**: Services return `Result<T>` (or `OneOf<T, Error>`) for expected failures — no exceptions for control flow
- **Guard clauses**: Validate at the top of a method, return early. No nested if/else pyramids.
- **CQRS-lite**: Separate read DTOs (lightweight, denormalized for the view) from write commands. Queries never trigger side effects.

## Frontend — Component Architecture

### Smart / Dumb split
- **Smart (container) components**: Connect to services, manage state, pass data down via `input()`. Named `*PageComponent` or `*ContainerComponent`.
- **Dumb (presentational) components**: Receive data via `input()`, emit events via `output()`. No service injection. Fully testable in isolation.

### BLOCKER violations
- A service injected into a presentational component
- An HTTP call made directly from a component (must go through a service)
- Business logic in a template (`@if` expressions more than a simple boolean, method calls that transform data)
- `NgRx` introduced for features where a service with signals is sufficient

### State rules
- Component-local ephemeral state → `signal()` in the component class
- Shared mutable state → service with `signal()` / `computed()`
- Never duplicate state across multiple services — single source of truth

## Both
- No circular imports between modules or layers
- New external dependencies require a brief justification in the PR body
- No `any` type — use proper types or `unknown` with type narrowing
