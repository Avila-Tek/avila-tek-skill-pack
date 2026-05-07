# Go — API Standards Reference

## Architecture

Hexagonal Architecture (Ports & Adapters). Domain has zero external dependencies. Adapters implement ports; ports are defined near the domain.

```
cmd/
  <service>/
    main.go          ← thin entrypoint (wiring only, ~80 lines max)
internal/
  <domain>/          ← one package per bounded context (users/, orders/)
    domain/          ← pure business logic, zero external imports
    ports/           ← interfaces (input + output ports)
    adapters/
      http/          ← HTTP handlers (input adapters)
      postgres/      ← DB repository implementations (output adapters)
      memory/        ← in-memory implementations for tests
pkg/                 ← shared public libraries (minimal)
api/                 ← OpenAPI specs
migrations/          ← sequential SQL migration files (001_, 002_...)
```

**Dependency rule:** `adapters → ports → domain`. Domain never imports adapters or ports.

## Domain Zone

Pure business logic. No database drivers, no HTTP libraries, no third-party packages.

```go
// internal/users/domain/user.go
package domain

import "errors"

type User struct {
  ID        string
  Email     string
  Name      string
}

var (
  ErrUserNotFound = errors.New("user not found")
  ErrEmailTaken   = errors.New("email already taken")
)

func NewUser(email, name string) (*User, error) {
  if email == "" { return nil, errors.New("email is required") }
  return &User{Email: email, Name: name}, nil
}
```

## Ports Zone

Interfaces defined where they are **consumed**, not where they are implemented. The HTTP handler defines the interface it needs — not the postgres package.

```go
// internal/users/ports/repository.go
package ports

type UserRepository interface {
  FindByID(ctx context.Context, id string) (*domain.User, error)
  FindByEmail(ctx context.Context, email string) (*domain.User, error)
  Save(ctx context.Context, user *domain.User) error
}
```

Keep interfaces small — one capability per interface. Compose when you need both:
```go
type UserFinder interface { FindByID(ctx context.Context, id string) (*User, error) }
type UserSaver  interface { Save(ctx context.Context, user *User) error }
type UserRepository interface { UserFinder; UserSaver }
```

**Accept interfaces, return structs** — functions that accept interfaces are flexible; functions that return concrete structs are predictable.

## Adapters: Postgres Repository

```go
// internal/users/adapters/postgres/repository.go
package postgres

type UserRepository struct { db *pgxpool.Pool }

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
  return &UserRepository{db: db}
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
  var u domain.User
  err := r.db.QueryRow(ctx, "SELECT id, email, name FROM users WHERE email = $1", email).
    Scan(&u.ID, &u.Email, &u.Name)
  if errors.Is(err, pgx.ErrNoRows) {
    return nil, domain.ErrUserNotFound  // translate to domain error
  }
  if err != nil {
    return nil, fmt.Errorf("querying user by email: %w", err)
  }
  return &u, nil
}
```

Use **sqlc** for type-safe SQL generation. Write SQL in `.sql` files, run `sqlc generate`, use generated functions in adapters. Never ORM.

## Adapters: HTTP Handler

```go
// internal/users/adapters/http/handler.go
package http

type userService interface {          // defined here, at the consumer
  Register(ctx context.Context, email, name string) (*domain.User, error)
  GetByID(ctx context.Context, id string) (*domain.User, error)
}

type Handler struct { svc userService }

func NewHandler(svc userService) *Handler { return &Handler{svc: svc} }

func (h *Handler) Routes() chi.Router {
  r := chi.NewRouter()
  r.Post("/", h.register)
  r.Get("/{id}", h.getByID)
  return r
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
  var req RegisterRequest
  if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
    renderError(w, http.StatusBadRequest, "invalid_request", "could not parse request body")
    return
  }
  if err := req.Validate(); err != nil {
    renderError(w, http.StatusUnprocessableEntity, "validation_error", err.Error())
    return
  }
  user, err := h.svc.Register(r.Context(), req.Email, req.Name)
  if err != nil {
    renderDomainError(w, err)
    return
  }
  render(w, http.StatusCreated, toUserResponse(user))
}
```

**Thin handlers:** decode → validate → call domain → encode. No business logic in handlers.

## Request/Response DTOs

Domain types are never serialized directly. Use dedicated DTO structs in the HTTP adapter:

```go
// internal/users/adapters/http/dto.go
type RegisterRequest struct {
  Email string `json:"email"`
  Name  string `json:"name"`
}
func (r RegisterRequest) Validate() error {
  if r.Email == "" { return errors.New("email is required") }
  return nil
}

type UserResponse struct {
  ID    string `json:"id"`
  Email string `json:"email"`
  Name  string `json:"name"`
}
func toUserResponse(u *domain.User) UserResponse {
  return UserResponse{ID: u.ID, Email: u.Email, Name: u.Name}
}
```

## Error Handling

**Always wrap with `%w` (not `%v`)** — preserves error chain for `errors.Is`/`errors.As`:
```go
return nil, fmt.Errorf("registering user: %w", err)
// chain reads: "registering user: querying by email: connection refused"
```

**Sentinel errors in domain:**
```go
var ErrUserNotFound = errors.New("user not found")

// Caller checks via errors.Is — works through entire chain
if errors.Is(err, domain.ErrUserNotFound) {
  renderError(w, http.StatusNotFound, "not_found", "user not found")
  return
}
```

**Error translation boundary:** each layer translates errors from the layer below:
- Postgres adapter: `pgx.ErrNoRows` → `domain.ErrUserNotFound`
- HTTP handler: `domain.ErrUserNotFound` → 404 response

**Log once at the boundary** where you stop propagating:
```go
// ✓ Log at HTTP handler (propagation stops here)
if err != nil {
  slog.ErrorContext(r.Context(), "failed to register user", "error", err)
  renderDomainError(w, err)
  return
}
// ✗ Never log at every propagation level — creates duplicate entries
```

**Consistent error responses:**
```go
type ErrorResponse struct {
  Code    string `json:"code"`
  Message string `json:"message"`
}

func renderDomainError(w http.ResponseWriter, err error) {
  switch {
  case errors.Is(err, domain.ErrUserNotFound):
    renderError(w, http.StatusNotFound, "not_found", "user not found")
  case errors.Is(err, domain.ErrEmailTaken):
    renderError(w, http.StatusConflict, "conflict", "email is already in use")
  default:
    slog.Error("unhandled domain error", "error", err)
    renderError(w, http.StatusInternalServerError, "internal_error", "an unexpected error occurred")
  }
}
```

## Router and Middleware

Prefer **Chi** (stdlib-compatible, composable):
```go
func NewRouter(userHandler *Handler, cfg *Config) http.Handler {
  r := chi.NewRouter()
  r.Use(middleware.RequestID)
  r.Use(middleware.RealIP)
  r.Use(RequestLogger(logger))
  r.Use(middleware.Recoverer)
  r.Use(middleware.Timeout(30 * time.Second))

  r.Get("/healthz", healthz)
  r.Route("/v1", func(r chi.Router) {
    r.Use(AuthMiddleware(cfg.JWTSecret))
    r.Mount("/users", userHandler.Routes())
  })
  return r
}
```

## Wiring in `cmd/`

```go
// cmd/api/main.go — wiring only, zero business logic
func main() {
  cfg := config.MustLoad()
  db  := postgres.MustConnect(cfg.DatabaseURL)

  userRepo    := postgresadapter.NewUserRepository(db)
  userSvc     := users.NewService(userRepo)
  userHandler := httphandler.NewUserHandler(userSvc)

  router := NewRouter(userHandler, cfg)
  log.Fatal(http.ListenAndServe(cfg.Addr, router))
}
```

## Data Access

Use **sqlc** for query generation:
```sql
-- queries/users.sql
-- name: GetUserByEmail :one
SELECT id, email, name FROM users WHERE email = $1;

-- name: InsertUser :one
INSERT INTO users (id, email, name) VALUES ($1, $2, $3) RETURNING *;
```

Use **goose** for migrations:
```sql
-- migrations/001_create_users.sql
-- +goose Up
CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, name TEXT NOT NULL);
-- +goose Down
DROP TABLE users;
```

Always write `Down` migrations. Apply at startup before serving traffic.

**Transactions:**
```go
tx, err := s.db.Begin(ctx)
if err != nil { return fmt.Errorf("starting transaction: %w", err) }
defer tx.Rollback(ctx)  // no-op if committed

if err := s.userRepo.SaveTx(ctx, tx, user); err != nil {
  return fmt.Errorf("saving user: %w", err)
}
return tx.Commit(ctx)
```

## Adding a New Feature (sequence)

1. `domain/` — model the concept, entity, sentinel errors (no infrastructure)
2. `ports/` — define the interface the domain needs
3. `adapters/postgres/` — implement the port
4. `adapters/http/` — handler + DTOs, define the service interface locally
5. `cmd/` — wire concrete adapters into domain service

## Red Flags

- Business logic inside HTTP handlers (belongs in domain)
- Domain importing any infrastructure package (`pgx`, `chi`, etc.)
- `fmt.Errorf("...: %v", err)` — loses error chain (use `%w`)
- `panic()` in business logic (only valid in `Must*` startup helpers)
- Logging at every propagation level (log once at boundary)
- Silently swallowed errors (`_`)
- ORM magic — write real SQL

## Verification Checklist

- [ ] `go build ./...` passes
- [ ] `go vet ./...` passes clean
- [ ] `golangci-lint run` passes
- [ ] `go test ./...` passes
- [ ] No direct infrastructure imports in `domain/` packages
- [ ] All errors wrapped with `%w` (not `%v`)
- [ ] `cmd/` entrypoints ≤ ~80 lines (wiring only)
