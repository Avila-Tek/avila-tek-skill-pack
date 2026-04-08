# 09 · Data Access

The data access layer bridges the domain and the database. Its job is to translate between domain types and persistence — nothing more. Business logic does not belong here, and SQL does not belong in the domain.

---

## The Repository Pattern

Every domain area exposes a repository interface (defined in `ports/`) that describes what persistence operations the domain needs. The concrete implementation lives in an adapter.

```go
// internal/users/ports/repository.go — the contract
package ports

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*domain.User, error)
    FindByEmail(ctx context.Context, email string) (*domain.User, error)
    Save(ctx context.Context, user *domain.User) error
    Delete(ctx context.Context, id string) error
}
```

```go
// internal/users/adapters/postgres/repository.go — the implementation
package postgres

type UserRepository struct {
    db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
    return &UserRepository{db: db}
}
```

The domain never imports the `postgres` package. It only knows about the `ports.UserRepository` interface.

---

## `sqlc` — Type-Safe SQL

We use [sqlc](https://sqlc.dev/) to generate type-safe Go code from SQL queries. You write SQL; sqlc generates the Go boilerplate. No ORM, no runtime reflection, no magic — just real SQL and real Go.

**Workflow:**

1. Write SQL queries in `.sql` files
2. Run `sqlc generate` → gets you typed Go functions and structs
3. Use the generated code in your repository adapter

**Setup (`sqlc.yaml`):**
```yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/users/adapters/postgres/queries"
    schema: "migrations"
    gen:
      go:
        package: "sqlcusers"
        out: "internal/users/adapters/postgres/sqlc"
        emit_interface: false
        emit_json_tags: true
```

**Queries file (`queries/users.sql`):**
```sql
-- name: GetUserByID :one
SELECT id, email, name, created_at
FROM users
WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, email, name, created_at
FROM users
WHERE email = $1;

-- name: InsertUser :one
INSERT INTO users (id, email, name, created_at)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

**Generated code (do not edit):**
```go
// sqlc/query.sql.go — auto-generated
func (q *Queries) GetUserByID(ctx context.Context, id string) (User, error) { ... }
func (q *Queries) InsertUser(ctx context.Context, arg InsertUserParams) (User, error) { ... }
```

**Repository uses the generated code:**
```go
// internal/users/adapters/postgres/repository.go
func (r *UserRepository) FindByID(ctx context.Context, id string) (*domain.User, error) {
    row, err := r.queries.GetUserByID(ctx, id)
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, domain.ErrUserNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("finding user by id: %w", err)
    }
    return toDomainUser(row), nil
}

// toDomainUser maps the sqlc-generated type to the domain type
func toDomainUser(row sqlcusers.User) *domain.User {
    return &domain.User{
        ID:        row.ID,
        Email:     row.Email,
        Name:      row.Name,
        CreatedAt: row.CreatedAt.Time,
    }
}
```

The mapping function is the only place where sqlc types and domain types meet. Keep it simple and keep it in the adapter.

---

## Database Driver: `pgx`

Use [pgx](https://github.com/jackc/pgx) as the PostgreSQL driver. It is significantly faster than `lib/pq`, has better type support (native `uuid`, `timestamptz`, arrays), and is the standard choice for modern Go Postgres applications.

```go
// Connecting with a connection pool (preferred for servers)
func MustConnect(dsn string) *pgxpool.Pool {
    pool, err := pgxpool.New(context.Background(), dsn)
    if err != nil {
        panic(fmt.Sprintf("connecting to database: %v", err))
    }

    if err := pool.Ping(context.Background()); err != nil {
        panic(fmt.Sprintf("pinging database: %v", err))
    }

    return pool
}
```

---

## Transactions

For operations that must succeed or fail together, use explicit transactions. Pass the transaction as a `pgx.Tx` through the repository, or use a Unit of Work pattern.

```go
// Repository method that accepts a transaction
func (r *UserRepository) SaveTx(ctx context.Context, tx pgx.Tx, user *domain.User) error {
    q := r.queries.WithTx(tx)
    _, err := q.InsertUser(ctx, sqlcusers.InsertUserParams{
        ID:        user.ID,
        Email:     user.Email,
        Name:      user.Name,
        CreatedAt: pgtype.Timestamptz{Time: user.CreatedAt, Valid: true},
    })
    return err
}
```

```go
// Service orchestrates the transaction
func (s *Service) RegisterWithProfile(ctx context.Context, email, name string) error {
    tx, err := s.db.Begin(ctx)
    if err != nil {
        return fmt.Errorf("starting transaction: %w", err)
    }
    defer tx.Rollback(ctx)  // No-op if already committed

    user, err := domain.NewUser(email, name)
    if err != nil {
        return err
    }

    if err := s.userRepo.SaveTx(ctx, tx, user); err != nil {
        return fmt.Errorf("saving user: %w", err)
    }

    if err := s.profileRepo.CreateTx(ctx, tx, user.ID); err != nil {
        return fmt.Errorf("creating profile: %w", err)
    }

    return tx.Commit(ctx)
}
```

---

## Migrations

Use [goose](https://github.com/pressly/goose) for migrations. Migrations are numbered SQL files in the `migrations/` directory.

```
migrations/
├── 001_create_users.sql
├── 002_add_orders_table.sql
└── 003_add_index_on_users_email.sql
```

```sql
-- migrations/001_create_users.sql
-- +goose Up
CREATE TABLE users (
    id         TEXT        PRIMARY KEY,
    email      TEXT        NOT NULL UNIQUE,
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- +goose Down
DROP TABLE users;
```

Run migrations at startup before the server accepts traffic:

```go
func main() {
    cfg := config.MustLoad()
    db := postgres.MustConnect(cfg.DatabaseURL)

    if err := runMigrations(db); err != nil {
        log.Fatal("running migrations:", err)
    }

    // ... rest of startup
}
```

---

## Anti-Patterns

### ❌ SQL in the domain layer
```go
// internal/users/domain/service.go
func (s *Service) Register(ctx context.Context, email string) error {
    s.db.Exec(ctx, "INSERT INTO users (email) VALUES ($1)", email)  // ❌
}
```
The domain should never know SQL exists. All data access goes through repository interfaces.

### ❌ Raw `map[string]interface{}` for query results
```go
rows, _ := db.Query("SELECT * FROM users")
for rows.Next() {
    row := make(map[string]interface{})
    // ...
}
```
Use `sqlc` or explicit scanning into typed structs. Maps lose type safety and don't fail at compile time.

### ❌ ORM magic
```go
db.Where("email = ?", email).First(&user)
db.Preload("Orders").Preload("Orders.Items").Find(&users)
```
Heavy ORM usage generates unpredictable SQL, makes performance tuning hard, and leaks ORM types into the domain. Write the SQL yourself — you control exactly what runs.

### ❌ Repository methods that return infrastructure types
```go
// ❌ The caller now depends on pgx — infrastructure leaks upward
func (r *UserRepository) FindByID(ctx context.Context, id string) (*pgx.Row, error) { ... }
```
Always map to domain types before returning.

### ❌ N+1 queries hidden in loops
```go
orders, _ := repo.FindAll(ctx)
for _, order := range orders {
    order.User, _ = userRepo.FindByID(ctx, order.UserID)  // N queries for N orders
}
```
Use JOINs or batch lookups. `sqlc` makes it easy to write the right query.

### ❌ Ignoring migration direction
Always write `Down` migrations. You will need to roll back someday.

---

[← Testing](./08-testing.md) | [Index](./README.md) | [Next: Configuration →](./10-configuration.md)
