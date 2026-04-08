# 01 · Project Layout

A consistent directory structure is the foundation everything else builds on. When the layout is predictable, any developer can navigate an unfamiliar service in minutes. When it's not, every file becomes a treasure hunt.

---

## Monorepo Structure

This project uses a **single Go module** at the repository root. All services share one `go.mod`, which keeps dependency management simple and enables easy sharing of internal packages.

```
/
├── cmd/                        # Binary entry points — one directory per deployable
│   ├── api/
│   │   └── main.go
│   └── worker/
│       └── main.go
│
├── internal/                   # Private application code — not importable externally
│   ├── users/                  # One directory per domain/service boundary
│   │   ├── domain/
│   │   ├── ports/
│   │   └── adapters/
│   ├── orders/
│   │   ├── domain/
│   │   ├── ports/
│   │   └── adapters/
│   └── shared/                 # Code shared across internal packages
│       ├── pagination/
│       └── timeutil/
│
├── pkg/                        # Code safe to import externally (libraries, SDKs)
│   └── apierrors/
│
├── api/                        # API contracts — OpenAPI specs, proto files
│   ├── openapi/
│   └── proto/
│
├── migrations/                 # Database migrations (numbered, sequential)
│
├── configs/                    # Static config files (not secrets)
│   └── golangci.yml
│
├── scripts/                    # Build, deploy, and maintenance scripts
│
├── docs/                       # Documentation (including these guidelines)
│
├── go.mod
├── go.sum
└── Taskfile.yml
```

---

## The Role of Each Directory

### `cmd/`
Each subdirectory represents a single deployable binary. `main.go` should be **thin** — its only job is to wire dependencies and start the server. Business logic never lives here.

```go
// cmd/api/main.go
func main() {
    cfg := config.MustLoad()
    db := postgres.MustConnect(cfg.DatabaseURL)

    userRepo   := postgresadapter.NewUserRepository(db)
    userSvc    := users.NewService(userRepo)
    userHandler := httphandler.NewUserHandler(userSvc)

    router := chi.NewRouter()
    router.Mount("/users", userHandler.Routes())

    log.Fatal(http.ListenAndServe(cfg.Addr, router))
}
```

### `internal/`
The Go toolchain enforces that packages under `internal/` cannot be imported by code outside the module root. This is your primary encapsulation boundary. All domain logic lives here.

Each subdirectory under `internal/` maps to a **domain area** (users, orders, billing). Inside each domain area, the structure follows the [architecture pattern](./03-architecture.md):

```
internal/users/
├── domain/          # Pure business logic — no external imports
│   ├── user.go
│   └── service.go
├── ports/           # Interfaces (what the domain needs and exposes)
│   ├── repository.go
│   └── service.go
└── adapters/        # Concrete implementations
    ├── http/
    │   └── handler.go
    ├── postgres/
    │   └── repository.go
    └── memory/      # In-memory implementation for tests
        └── repository.go
```

### `pkg/`
Code in `pkg/` is designed to be reused across multiple projects. Keep this small. If something only makes sense within this codebase, it belongs in `internal/shared/` instead.

### `api/`
Contracts live here: OpenAPI specs, Protocol Buffer definitions, and any other machine-readable interface descriptions. These are the source of truth for what the API exposes.

### `migrations/`
Sequential, numbered SQL migration files. Managed by a migration tool (see [Data Access](./09-data-access.md)).

```
migrations/
├── 001_create_users.sql
├── 002_add_orders_table.sql
└── 003_add_index_on_email.sql
```

---

## Rules

- **`main.go` is for wiring, not logic.** If `main.go` is longer than ~80 lines, something is wrong.
- **One binary per `cmd/` subdirectory.** Never put multiple `main` packages in the same directory.
- **Domain areas in `internal/` reflect business boundaries, not technical layers.** No `internal/handlers/`, `internal/repositories/` — those are layers inside a domain area, not top-level directories.
- **Shared utilities go in `internal/shared/`**, not in a package called `utils` or `helpers`.

---

## Anti-Patterns

### ❌ Layer-based top-level structure
```
internal/
├── handlers/      # All HTTP handlers for all domains
├── services/      # All service logic for all domains
├── repositories/  # All DB access for all domains
└── models/        # All structs for all domains
```
This structure couples unrelated domains. Adding a feature to `users` requires touching four separate directories. A change in `orders` can accidentally break `users` because they share the same package. As the codebase grows, every directory becomes a sprawl.

### ❌ Flat structure (everything in one package)
```
internal/
├── user.go
├── user_handler.go
├── user_service.go
├── order.go
├── order_handler.go
...
```
Works for the first 500 lines. Becomes unmaintainable at scale. There are no encapsulation boundaries, and all types are visible to all other types.

### ❌ Overusing `pkg/`
```
pkg/
├── users/
├── orders/
├── auth/
└── everything-else/
```
`pkg/` signals "this is a reusable library." If your business logic is in `pkg/`, it's in the wrong place. Move it to `internal/`.

### ❌ Business logic in `cmd/`
```go
// cmd/api/main.go — DON'T do this
func main() {
    // ...
    http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
        rows, err := db.Query("SELECT * FROM users")
        // ...
    })
}
```

---

[← Index](./README.md) | [Next: Package Design →](./02-package-design.md)
