# Go — Code Review Reference

## Package Design

- Package names: lowercase, singular, no underscores (`user`, `order`, not `users`, `user_service`)
- **No utility packages** (`utils/`, `helpers/`, `common/`) — these are dumping grounds that hide boundaries. Move code to the package that owns the concept.
- **No `models/` or `types/` packages** — types belong in the package that defines their behavior, not in a shared grab-bag
- One package per bounded context (`internal/users/`, `internal/orders/`)
- Package should be cohesive: everything in it belongs together by concept

## Architecture Red Flags

These are blocking findings in a code review:

- Business logic inside HTTP handlers — handlers must be thin: decode → validate → call domain → encode
- Domain package importing infrastructure (`pgx`, `chi`, `http`, any external library) — domain must have zero external dependencies
- Adapter importing another adapter directly — adapters communicate through domain/ports, not each other
- `fmt.Errorf("...: %v", err)` — loses the error chain. Must use `%w` to preserve `errors.Is`/`errors.As` traversal
- `panic()` in business logic — valid only in `Must*` startup helpers, never in domain or service code
- Logging at every propagation level — log once at the boundary where propagation stops (HTTP handler)
- Silently swallowed errors: `_, err := something(); _ = err` or ignoring `err` with `_`
- ORM usage — write real SQL with sqlc

## Error Handling

```go
// ✅ Always wrap with %w — preserves error chain
return nil, fmt.Errorf("registering user: %w", err)

// ❌ %v loses the chain — errors.Is() won't traverse it
return nil, fmt.Errorf("registering user: %v", err)
```

Error translation boundary: each layer translates errors from the layer below:

```
Postgres adapter: pgx.ErrNoRows → domain.ErrUserNotFound
HTTP handler: domain.ErrUserNotFound → 404 response
```

Log once at the HTTP boundary — not at service or domain level:

```go
// ✅ Log at the handler (propagation stops here)
if err != nil {
    slog.ErrorContext(r.Context(), "failed to register user", "error", err)
    renderDomainError(w, err)
    return
}
```

## Interface Design

- Interfaces defined where they are **consumed**, not where they are implemented
- Keep interfaces small — one capability per interface. Compose where needed:

```go
// ✅ Small, focused interfaces
type UserFinder interface { FindByID(ctx context.Context, id string) (*User, error) }
type UserSaver  interface { Save(ctx context.Context, user *User) error }

// Composed when both are needed
type UserRepository interface { UserFinder; UserSaver }
```

- Accept interfaces, return structs — functions that accept interfaces are flexible; functions that return concrete structs are predictable
- Avoid interface with a single method named after the implementation — `type Reader interface { Read(...) }` over `type FileReader interface { ReadFile(...) }`

## Concurrency

- Always document goroutine ownership — who starts it, who waits for it, who stops it
- Use `context.Context` for cancellation propagation — pass it as the first argument
- Channels for communication, mutexes for state — never mix the two patterns for the same concern
- No goroutine leaks: every goroutine started must have a defined exit path

## Verification Checklist

- [ ] `go build ./...` — compiles clean
- [ ] `go vet ./...` — no vet issues
- [ ] `golangci-lint run` — passes
- [ ] `go test ./...` — all unit tests pass
- [ ] `go test -tags=integration ./...` — integration tests pass (if applicable)
- [ ] No infrastructure imports in `domain/` packages
- [ ] All errors wrapped with `%w`, not `%v`
- [ ] `cmd/` entrypoints ≤ ~80 lines (wiring only)
- [ ] No `utils/`, `helpers/`, `models/`, or `types/` packages introduced
- [ ] No business logic in HTTP handlers
- [ ] No silently swallowed errors (`_`)
