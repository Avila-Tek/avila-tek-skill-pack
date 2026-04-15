---
stack: go
label: "Go"
type: backend
detection:
  files:
    - "go.mod"
---

# Stack: Go

## Summary

Go backend service. Hexagonal Architecture (Ports & Adapters). Uses sqlc or pgx for data access, slog for structured logging, Testcontainers for DB integration tests. No framework — standard library HTTP or Chi/Fiber for routing.

## Architecture Overview

```
cmd/
  <service>/
    main.go          ← thin entrypoint (wiring only)
internal/
  <domain>/          ← one package per bounded context (users/, orders/)
    domain/          ← pure business logic, zero external deps
    ports/           ← interfaces (input + output ports)
    adapters/
      http/          ← HTTP handlers (input adapters)
      postgres/      ← DB repository implementations (output adapters)
      memory/        ← in-memory implementations for tests
pkg/                 ← shared public libraries (minimal)
api/                 ← OpenAPI specs
migrations/          ← sequential SQL migration files
```

## Key Patterns

- **Hexagonal Architecture** — adapters → ports → domain; domain has zero external imports
- **Domain-driven packages** — `internal/` organized by domain (users/, orders/), NOT by layer
- **Ports as interfaces** — domain defines what it needs; adapters implement those interfaces
- **Error wrapping with %w** — always wrap with context (`fmt.Errorf("getting user: %w", err)`), never `%v`
- **Sentinel errors in domain** — `domain.ErrUserNotFound`, `domain.ErrEmailTaken`; translate at HTTP boundary
- **Log once at the boundary** — HTTP handler logs the error; never log at every propagation level
- **Table-driven tests** — all unit tests use `[]struct{ name, input, want }` pattern
- **Thin cmd/ entrypoints** — `main.go` only wires dependencies; zero business logic

## Standards Documents

Standards live in `stacks/go/agent_docs/`:

| File | Content |
|------|---------|
| `01-project-layout.md` | Directory structure, package conventions, module setup |
| `02-package-design.md` | Package naming, visibility, avoiding circular deps |
| `03-architecture.md` | Hexagonal architecture, layer boundaries |
| `04-interface-design.md` | Interface contracts, small interfaces, Hyrum's Law |
| `05-error-handling.md` | Error wrapping, sentinel errors, error types |
| `06-dependency-injection.md` | Constructor injection, wire, avoiding globals |
| `07-concurrency.md` | Goroutines, channels, sync primitives, race conditions |
| `08-testing.md` | Table-driven tests, testify, integration tests, mocks |
| `09-data-access.md` | sqlc/pgx patterns, transactions, migrations |
| `10-configuration.md` | Config structs, environment variables, validation |
| `11-observability.md` | Structured logging (slog), metrics, tracing |
| `12-http-layer.md` | HTTP handlers, middleware, OpenAPI |
| `13-tooling.md` | Makefile, golangci-lint, CI/CD, Docker |

## Required Reading by Task Type

After reading this file, Read the `agent_docs` files listed for your task type. Do not proceed until those Reads are complete.

| Task type | Read these files |
|-----------|-----------------|
| Any implementation | `agent_docs/01-project-layout.md`, `agent_docs/03-architecture.md`, `agent_docs/05-error-handling.md` |
| API / new endpoints | Any implementation + `agent_docs/12-http-layer.md`, `agent_docs/04-interface-design.md` |
| Data access | Any implementation + `agent_docs/09-data-access.md` |
| Concurrency | Any implementation + `agent_docs/07-concurrency.md` |
| Testing | `agent_docs/08-testing.md` |
| Code review | `agent_docs/01-project-layout.md`, `agent_docs/03-architecture.md`, `agent_docs/05-error-handling.md` |
| Observability | Any implementation + `agent_docs/11-observability.md` |
| Configuration | Any implementation + `agent_docs/10-configuration.md` |

## Testing Conventions

- Domain tests: no mocks, no DB — pure Go logic, fast and numerous
- Adapter tests: HTTP with `httptest.NewRecorder()`, DB with `testcontainers` (build tag `//go:build integration`)
- In-memory implementations preferred over mock frameworks for domain mocks
- `mockery` for generating adapter-level mocks when needed
- `testify` for assertions (`assert` = non-fatal, `require` = fatal)

## Red Flags

- Business logic inside HTTP handlers (belongs in domain)
- Domain package importing any infrastructure package
- `fmt.Errorf("...: %v", err)` — loses error chain (use `%w`)
- `panic()` in business logic (only valid in `Must*` startup helpers)
- Global variables shared across packages
- Silently swallowed errors — missing error return or blank identifier `_`

## Verification Checklist

- [ ] `go build ./...` passes with no errors
- [ ] `go vet ./...` passes clean
- [ ] `golangci-lint run` passes (or failing rules have documented suppressions)
- [ ] `go test ./...` passes; integration tests pass with `-tags integration`
- [ ] No direct infrastructure imports in `domain/` packages
- [ ] All errors wrapped with `%w` (not `%v`)
