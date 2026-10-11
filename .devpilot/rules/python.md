# Python Rules
> APPLIES ONLY IF `project.config.md → stack.backend = python`.

- Python 3.11+. One virtual environment per project (`.venv/`, gitignored); dependencies pinned in
  `requirements.txt` (or `pyproject.toml`) — never `pip install` something the file doesn't list.
- Type hints on every function signature and module-level constant; `from __future__ import annotations`
  where forward references need it. No `Any` without a comment saying why; narrow `object` instead.
- Layering: HTTP/transport (FastAPI routers, agent entrypoints) → service (business logic) → repository /
  adapter (files, DB, external APIs). Handlers stay thin; no business logic in a route or a tool callback.
- `async def` all the way for I/O; never block the event loop (`time.sleep`, sync HTTP, sync file I/O in
  hot paths). Wrap unavoidable blocking calls in `asyncio.to_thread`.
- Config from the environment only (`os.environ` / `pydantic-settings`), loaded once at startup; no
  secrets in code, logs, or committed `.env` files (`.env.example` documents the keys).
- Validate every input at the edge with Pydantic models; request/response schemas are typed, never raw `dict`.
- Errors: raise typed exceptions (`class OrderNotFound(Exception)`) in services; map them to HTTP status
  codes in one exception handler. Never `except Exception: pass`.
- Logging via `logging.getLogger(__name__)` with structured `extra=` fields, no `print()`, no PII or tokens.
- Voice / LLM agents (LiveKit, Gemini, OpenAI): prompts live in versioned files (`prompt.md`), tool
  functions are pure and unit-testable, every call has a time and silence limit, and usage/cost is logged.
- Lint + format with `ruff` (config in `pyproject.toml` / `ruff.toml`); type-check with `mypy` or `pyright`
  when the project has it configured. Fix findings — never silence with blanket ignores.
- Tests: `pytest` mirroring the code (`tests/test_<module>.py`); unit tests for services + one failure
  branch; integration tests per endpoint with `httpx.AsyncClient` against the real app
  (`.claude/skills/python-testing/SKILL.md`). External services are faked at the adapter boundary.
- Build + test before commit via `bash scripts/run-tests.sh python`.
