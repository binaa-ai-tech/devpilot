---
name: python-testing
description: "pytest unit tests and httpx integration tests for FastAPI / asyncio services; fakes at the adapter boundary; assertion quality and test anti-patterns."
when_to_use: "When writing or fixing Python tests."
paths:
  - "**/test_*.py"
  - "**/*_test.py"
  - "**/conftest.py"
  - "**/tests/**/*.py"
user-invocable: false
---
# Python Testing — pytest units + real-app integration tests

Load this **when writing or fixing Python tests.** Default stack: **pytest**, **pytest-asyncio**
(`asyncio_mode = "auto"`), **httpx.AsyncClient** with `ASGITransport` for FastAPI, and
`unittest.mock` / `pytest-mock` for fakes. Match the repo's existing choices; don't add a second
assertion or mocking library.

## Layout
- `tests/` at the service root, mirroring the code: `agent/order_service.py` → `tests/test_order_service.py`.
- `tests/conftest.py` holds shared fixtures (settings with test values, a temp data dir, the app client).
- `pytest.ini` / `[tool.pytest.ini_options]` in `pyproject.toml` sets `testpaths = ["tests"]` and
  `asyncio_mode = "auto"`. Test dependencies live in `requirements-dev.txt` or `[project.optional-dependencies].dev`.

## What to test where
| Code | Test | How |
|------|------|-----|
| Services / business rules / tool functions | Unit | Pure calls, fakes for adapters; no network, no SDK |
| Pydantic schemas / validators | Unit | Valid case + each rule's failing case (`pytest.raises(ValidationError)`) |
| FastAPI endpoints (routing, status codes, JSON shape, errors) | Integration | `httpx.AsyncClient(transport=ASGITransport(app=app))` |
| File / DB adapters | Integration | Real files under `tmp_path`; real DB in a container when the project has one |
| Voice / LLM agent flows | Unit on tools + one scripted session test with a fake LLM | Never hit a paid model in CI |

## Unit tests
- Name as behavior: `test_create_order_rejects_item_not_on_menu`.
- Arrange → Act → Assert, one behavior per test; `@pytest.mark.parametrize` for boundaries.
- Assert on returned values and observable calls (`fake_repo.saved == [...]`), not private state.
- Inject time and randomness (`clock=lambda: fixed_dt`); never patch `datetime.now` globally.

## Integration tests (the part that catches real bugs)
- Build the app with **test settings** (temp data dir, fake API keys) via a fixture; replace only
  **external** adapters (LiveKit, Gemini, payment) with fakes registered through dependency overrides
  or constructor injection — never monkeypatch deep inside the SDK.
- One test per endpoint per AC plus one 4xx path. Assert status code **and** the JSON body
  (parse into the response model).
- Each test owns its data (`tmp_path`, fresh fixtures); no test depends on another's leftovers.
- Secrets come from the fixture, never from the developer's real `.env`.

## Tests that lie — never ship these
- No assertion, or one that can't fail (`assert True`, `assert result is not None` alone).
- `pytest.raises(Exception)` — assert the exact exception type and message.
- `time.sleep` / `asyncio.sleep` for synchronization; `await` the thing you are waiting for.
- `try: … except: pass` around the act step; commented-out asserts; `# noqa` on a failing assert.
- A test that calls a real model, a real phone number, or the internet.

## Running
- `bash scripts/run-tests.sh python` (token-lean: full log in `.devpilot/logs/python.log`, failures only
  in context). Narrow with `-- -k order` or `-- tests/test_order_service.py`.
- Coverage when the project tracks it: `pytest --cov=<package> --cov-fail-under=<repo value>`.
