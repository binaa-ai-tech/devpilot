# Go Rules
> APPLIES ONLY IF `project.config.md → stack.backend = go`.

- Format with `gofmt`/`goimports`; code must pass `go vet`.
- Handle every error explicitly — no `_ =` discarding errors that matter. Wrap with context: `fmt.Errorf("doing X: %w", err)`.
- Accept interfaces, return structs. Keep interfaces small and defined by the consumer.
- Use `context.Context` as the first arg for I/O / request-scoped calls; honor cancellation.
- Guard shared state with mutexes or channels; run race-sensitive tests with `go test -race`.
- No global mutable state; inject dependencies.
- Layer it: handler → service → repository. Keep packages cohesive; avoid `util` dumping grounds.
- Tests with the standard `testing` package, table-driven where it fits; `*_test.go` next to the code.
- Verify before commit: `go build ./...` && `go test ./...`.
