# Python Backend Rules
> APPLIES ONLY IF `project.config.md → stack.backend = python`.

- Type hints on all public functions; run `mypy`/`pyright` if the project configures it.
- Follow PEP 8; format with the project's tool (black/ruff) — don't hand-format.
- Layer it: route/view → service → repository/model. Keep views thin.
- Validate input with pydantic / serializers at the edge.
- Config from environment (12-factor); no secrets in code. Use `os.environ` via a settings module.
- Use the project's framework conventions (FastAPI/Django/Flask) — don't mix paradigms.
- Tests with `pytest` next to the code (`test_*.py`); cover happy path + one error/edge branch.
- Verify before commit: import/compile check (`python -m compileall .`) && `pytest`.
