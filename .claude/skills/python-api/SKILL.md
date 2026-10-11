---
name: python-api
description: "How to build Python backends: FastAPI endpoints, Pydantic schemas, async I/O, typed errors, settings, logging, and LiveKit / LLM agent services that stay testable."
when_to_use: "Before adding or changing an endpoint, schema, agent tool, or cross-cutting concern in a Python service."
paths:
  - "**/*.py"
user-invocable: false
---
# Python API & Agent Development — services that are safe to depend on

Load this **before adding or changing a FastAPI endpoint, a Pydantic schema, an agent tool, or a
cross-cutting concern** in a Python backend. Targets Python 3.11+. `rules/python.md` holds the
one-liners; this is the how.

## Shape
- Follow the project's layout — a single `server.py` / `agent.py` app, or a package with
  `routers/`, `services/`, `adapters/`. Don't introduce a second structure.
- Thin transport → service → adapter (`architecture-guard`):
  - **Router / agent entrypoint:** parse input, call one service function, map the result. No logic.
  - **Service:** all business rules, pure where possible, takes its dependencies as arguments.
  - **Adapter / repository:** files, databases, HTTP, LLM and voice SDKs. Nothing else touches them.
- Resources are nouns, verbs are HTTP: `GET /orders`, `POST /orders`. Return `201` + the created
  resource on POST; `204` on delete.
- **Pydantic models at the boundary** (`class CreateOrderRequest(BaseModel)`, `OrderResponse`);
  never return raw `dict`s or ORM objects. `model_config = ConfigDict(extra="forbid")` on requests.
- `async def` handlers; every outbound call awaited with a timeout (`httpx.AsyncClient(timeout=…)`).
  Blocking SDK calls go through `asyncio.to_thread`.

## Settings & secrets
- One `Settings` object (`pydantic-settings` or a frozen dataclass read from `os.environ`) built
  once at startup and injected — modules never read `os.getenv` at import time for anything that
  can change per environment.
- Secrets only from the environment; `.env.example` lists every key with a placeholder.
  `load_dotenv()` is for local dev and must not override real environment variables.

## Errors
- Typed domain exceptions in services (`OrderNotFound`, `MenuItemUnavailable`); one
  `@app.exception_handler` per family maps them to status codes and a stable JSON error shape
  (`{"error": {"code": "...", "message": "..."}}`). Never leak stack traces or secrets.
- `HTTPException` is fine at the edge for pure transport errors (401/403/404 on a missing route
  parameter); business failures travel as typed exceptions or a `Result`-style return.
- Never `except Exception: pass`; catch the narrowest type, log once with context, re-raise or map.

## Agents (LiveKit / Gemini / OpenAI voice & chat)
- Prompts are **files** (`prompt.md`), versioned and reviewed like code; the agent reads them at
  startup. No prompt text concatenated inline in Python.
- Tool functions (`@function_tool`) are thin: validate arguments with Pydantic, call a service,
  return a typed result. The service is unit-tested without the SDK.
- Every session has a **hard time limit**, a **silence timeout**, and a cleanup path that always
  runs (`try/finally`): save the transcript, log usage + cost, close the room.
- Model names, voices, prices and limits come from settings, not literals scattered in the module.
- Log one structured line per call (`call_id`, duration, tokens in/out, cost, outcome) — that line
  is what ops dashboards and QA read.

## Operability
- `logging.getLogger(__name__)`; configure handlers once in the entrypoint. Message templates +
  `extra=` fields, never f-strings with user data, never tokens or phone numbers.
- Health endpoint (`GET /healthz`) that checks only the process, plus a readiness check for
  dependencies when the project has them.
- Long-running agents: handle `SIGTERM` (drain, then exit), bound queues, and never swallow
  `asyncio.CancelledError`.

## Ship-with
- [ ] Pydantic request/response models + validation on every new endpoint or tool.
- [ ] Typed exceptions mapped to status codes; stable error JSON; no stack traces leaked.
- [ ] Settings injected, no new `os.getenv` at import time, `.env.example` updated.
- [ ] `ruff check` + `ruff format --check` clean; type checker clean when configured.
- [ ] Unit test per service function + one integration test per endpoint (`python-testing`),
      verified with `bash scripts/run-tests.sh python`.
