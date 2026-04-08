# 03 · Architecture

We use **Hexagonal Architecture** (also known as Ports & Adapters). The goal is a codebase where the business logic is completely isolated from infrastructure — databases, HTTP, queues, caches. This makes the domain easy to test, easy to reason about, and resilient to infrastructure changes.

---

## The Three Zones

```
┌─────────────────────────────────────────────┐
│                  Adapters                   │  ← HTTP handlers, DB repos, queue consumers
│  ┌───────────────────────────────────────┐  │
│  │               Ports                   │  │  ← Interfaces (the contracts)
│  │  ┌─────────────────────────────────┐  │  │
│  │  │            Domain               │  │  │  ← Pure business logic
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Domain
The heart of the application. Contains business rules, entities, and service logic. **Has zero external dependencies** — no database drivers, no HTTP libraries, no third-party packages.

### Ports
Interfaces that define what the domain needs from the outside world (output ports: repositories, email senders, etc.) and what it exposes to the outside world (input ports: service interfaces consumed by handlers).

### Adapters
Concrete implementations of ports. An HTTP handler is an adapter. A Postgres repository is an adapter. A Redis cache is an adapter. Adapters know about the domain, but the domain knows nothing about adapters.

---

## The Dependency Rule

**Dependencies always point inward.** Adapters depend on ports. Ports are defined near the domain. The domain depends on nothing.

```
adapters → ports → domain
```

Never:
```
domain → adapters       ❌ (domain importing a DB driver)
domain → ports          ❌ (domain shouldn't import its own ports)
```

---

## Directory Mapping

```
internal/users/
├── domain/
│   ├── user.go          # The User entity and its business rules
│   └── service.go       # UserService — orchestrates domain logic
├── ports/
│   ├── repository.go    # UserRepository interface (output port)
│   └── service.go       # UserService interface (input port, consumed by HTTP handler)
└── adapters/
    ├── http/
    │   ├── handler.go   # HTTP handler — translates HTTP ↔ domain
    │   └── dto.go       # Request/response structs
    ├── postgres/
    │   └── repository.go # Implements ports.UserRepository using pgx
    └── memory/
        └── repository.go # Implements ports.UserRepository in-memory (for tests)
```

---

## What Goes Where

### Domain (`domain/`)

- Business entities and their invariants
- Service methods that orchestrate business operations
- No `import` of database drivers, HTTP libraries, or third-party packages
- No knowledge of how data is persisted or how requests arrive

```go
// internal/users/domain/user.go
package domain

import (
    "errors"
    "time"
)

type User struct {
    ID        string
    Email     string
    Name      string
    CreatedAt time.Time
}

var ErrEmailTaken = errors.New("email already taken")
var ErrUserNotFound = errors.New("user not found")

func NewUser(email, name string) (*User, error) {
    if email == "" {
        return nil, errors.New("email is required")
    }
    return &User{
        Email: email,
        Name:  name,
    }, nil
}
```

```go
// internal/users/domain/service.go
package domain

import "context"

type Service struct {
    repo UserRepository // depends on the interface, not a concrete type
}

func NewService(repo UserRepository) *Service {
    return &Service{repo: repo}
}

func (s *Service) Register(ctx context.Context, email, name string) (*User, error) {
    existing, err := s.repo.FindByEmail(ctx, email)
    if err != nil && !errors.Is(err, ErrUserNotFound) {
        return nil, fmt.Errorf("checking existing email: %w", err)
    }
    if existing != nil {
        return nil, ErrEmailTaken
    }

    user, err := NewUser(email, name)
    if err != nil {
        return nil, err
    }

    if err := s.repo.Save(ctx, user); err != nil {
        return nil, fmt.Errorf("saving user: %w", err)
    }

    return user, nil
}
```

Notice: `UserRepository` is referenced here but defined in `ports/` — the domain uses the interface shape without importing anything concrete.

### Ports (`ports/`)

```go
// internal/users/ports/repository.go
package ports

import (
    "context"
    "myapp/internal/users/domain"
)

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*domain.User, error)
    FindByEmail(ctx context.Context, email string) (*domain.User, error)
    Save(ctx context.Context, user *domain.User) error
}
```

```go
// internal/users/ports/service.go
package ports

import (
    "context"
    "myapp/internal/users/domain"
)

type UserService interface {
    Register(ctx context.Context, email, name string) (*domain.User, error)
    GetByID(ctx context.Context, id string) (*domain.User, error)
}
```

### Adapters (`adapters/`)

```go
// internal/users/adapters/http/handler.go
package http

import (
    "encoding/json"
    "net/http"

    "myapp/internal/users/ports"
    "github.com/go-chi/chi/v5"
)

type Handler struct {
    svc ports.UserService
}

func NewHandler(svc ports.UserService) *Handler {
    return &Handler{svc: svc}
}

func (h *Handler) Routes() chi.Router {
    r := chi.NewRouter()
    r.Post("/", h.register)
    r.Get("/{id}", h.getByID)
    return r
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    var req RegisterRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        renderError(w, http.StatusBadRequest, "invalid request body")
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

```go
// internal/users/adapters/postgres/repository.go
package postgres

import (
    "context"
    "errors"

    "myapp/internal/users/domain"
    "github.com/jackc/pgx/v5/pgxpool"
)

type UserRepository struct {
    db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
    return &UserRepository{db: db}
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
    var u domain.User
    err := r.db.QueryRow(ctx,
        "SELECT id, email, name, created_at FROM users WHERE email = $1", email,
    ).Scan(&u.ID, &u.Email, &u.Name, &u.CreatedAt)

    if errors.Is(err, pgx.ErrNoRows) {
        return nil, domain.ErrUserNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("querying user by email: %w", err)
    }

    return &u, nil
}
```

---

## Adding a New Feature

When adding a new feature, the flow is always the same:

1. **Start in `domain/`** — model the business concept and logic, no infrastructure.
2. **Define the port** — what interface does the domain need to interact with the outside?
3. **Implement the adapter** — make the HTTP handler or DB repo satisfy that interface.
4. **Wire it in `cmd/`** — inject the concrete adapter into the domain service.

This order keeps the design clean: infrastructure follows domain, never the other way around.

---

## Anti-Patterns

### ❌ Business logic in HTTP handlers
```go
func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    // Validation, DB queries, business rules — all jammed in here.
    // Untestable without a real HTTP server and database.
    rows, err := h.db.Query("SELECT * FROM users WHERE email = $1", req.Email)
    if rows.Next() {
        http.Error(w, "email taken", 409)
        return
    }
    // ...
}
```

### ❌ Domain importing infrastructure
```go
// internal/users/domain/service.go
import "github.com/jackc/pgx/v5"  // ❌ Domain should never know about pgx

func (s *Service) Register(ctx context.Context, email string) error {
    // Directly querying the DB from domain logic
    s.db.Exec(ctx, "INSERT INTO users ...")
}
```

### ❌ Skipping ports and depending directly on adapters
```go
// internal/users/adapters/http/handler.go
import "myapp/internal/users/adapters/postgres" // ❌ Adapter importing another adapter

type Handler struct {
    repo *postgres.UserRepository // ❌ Depends on concrete type, not interface
}
```
Now you can't swap the repository for an in-memory implementation in tests.

### ❌ Anemic domain model
```go
// domain has no behavior — just data bags
type User struct {
    ID    string
    Email string
}
// All logic lives in a "service" god object that doesn't belong anywhere
```
If your domain types are plain structs with no methods, and all logic lives in one massive `service.go`, the domain is not doing its job. Business rules should live on the types that own them.

---

[← Package Design](./02-package-design.md) | [Index](./README.md) | [Next: Interface Design →](./04-interface-design.md)
