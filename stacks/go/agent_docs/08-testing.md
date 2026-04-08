# 08 · Testing

Good tests give you confidence to refactor and ship. Bad tests give you a false sense of security and slow down development. The goal is a test suite that is fast, deterministic, easy to read, and tests behavior — not implementation.

---

## The Test Pyramid in a Hexagonal Codebase

The [hexagonal architecture](./03-architecture.md) naturally produces a healthy test pyramid:

```
           ┌──────┐
          /  e2e   \        Slow, few — full stack from HTTP to DB
         /──────────\
        / integration \     Medium — adapters against real infrastructure
       /──────────────\
      /   unit tests   \    Fast, many — domain logic with no infrastructure
     /──────────────────\
```

- **Domain tests** — no mocks, no databases, just pure Go. Fast and numerous. Test all business rules here.
- **Adapter tests** — test HTTP handlers with `httptest`, test DB repos with real DBs via `testcontainers`.
- **E2E tests** — test the full stack via HTTP. Few, for critical paths only.

---

## Table-Driven Tests

Table-driven tests are the idiomatic Go way to cover multiple scenarios cleanly. They reduce boilerplate, make it easy to add cases, and document the expected behavior inline.

```go
func TestUserService_Register(t *testing.T) {
    tests := []struct {
        name      string
        email     string
        wantErr   error
    }{
        {
            name:    "valid email registers successfully",
            email:   "alice@example.com",
            wantErr: nil,
        },
        {
            name:    "empty email returns validation error",
            email:   "",
            wantErr: domain.ErrInvalidEmail,
        },
        {
            name:    "duplicate email returns conflict error",
            email:   "existing@example.com",
            wantErr: domain.ErrEmailTaken,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            repo := memory.NewUserRepository()
            if tt.email == "existing@example.com" {
                _ = repo.Save(context.Background(), &domain.User{Email: tt.email})
            }

            svc := domain.NewService(repo)
            _, err := svc.Register(context.Background(), tt.email, "Test User")

            assert.ErrorIs(t, err, tt.wantErr)
        })
    }
}
```

---

## Domain Tests Need No Mocks

Because domain logic depends only on interfaces (see [Architecture](./03-architecture.md)), you can test it with in-memory implementations — no mock framework required.

```go
// internal/users/adapters/memory/repository.go
package memory

type UserRepository struct {
    mu    sync.RWMutex
    store map[string]*domain.User
}

func NewUserRepository() *UserRepository {
    return &UserRepository{store: make(map[string]*domain.User)}
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    for _, u := range r.store {
        if u.Email == email {
            return u, nil
        }
    }
    return nil, domain.ErrUserNotFound
}

func (r *UserRepository) Save(ctx context.Context, user *domain.User) error {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.store[user.ID] = user
    return nil
}
```

Domain tests are instant — no network, no disk. This is where you should have the most test coverage.

---

## Mocking With `mockery`

For adapter tests (HTTP handlers, etc.) where you need to mock a service interface, use [mockery](https://github.com/vektra/mockery) to generate mocks from interfaces.

```bash
# Install
go install github.com/vektra/mockery/v2@latest

# Generate mocks for all interfaces in the ports package
mockery --dir=internal/users/ports --output=internal/users/mocks --all
```

```go
// Test using a generated mock
func TestUserHandler_Register_Success(t *testing.T) {
    mockSvc := mocks.NewUserService(t)
    mockSvc.On("Register", mock.Anything, "alice@example.com", "Alice").
        Return(&domain.User{ID: "1", Email: "alice@example.com"}, nil)

    handler := httphandler.NewUserHandler(mockSvc)

    req := httptest.NewRequest(http.MethodPost, "/users", body(`{
        "email": "alice@example.com",
        "name": "Alice"
    }`))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    handler.Routes().ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)
    mockSvc.AssertExpectations(t)
}
```

---

## Testing HTTP Handlers With `httptest`

Use `net/http/httptest` to test HTTP handlers without starting a real server:

```go
func TestUserHandler_GetByID_NotFound(t *testing.T) {
    mockSvc := mocks.NewUserService(t)
    mockSvc.On("GetByID", mock.Anything, "nonexistent").
        Return(nil, domain.ErrUserNotFound)

    handler := httphandler.NewUserHandler(mockSvc)

    req := httptest.NewRequest(http.MethodGet, "/users/nonexistent", nil)
    w := httptest.NewRecorder()

    handler.Routes().ServeHTTP(w, req)

    assert.Equal(t, http.StatusNotFound, w.Code)

    var response map[string]string
    json.NewDecoder(w.Body).Decode(&response)
    assert.Equal(t, "not_found", response["code"])
}
```

---

## Integration Tests With `testcontainers`

Test DB adapters against a real database using [testcontainers-go](https://golang.testcontainers.org/). This catches SQL syntax errors, migration issues, and constraint violations that mocks can't.

```go
// internal/users/adapters/postgres/repository_integration_test.go
//go:build integration

package postgres_test

import (
    "testing"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
)

func TestUserRepository_FindByEmail(t *testing.T) {
    ctx := context.Background()

    container, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections"),
        ),
    )
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    dsn, _ := container.ConnectionString(ctx, "sslmode=disable")
    db := postgres.MustConnect(dsn)
    runMigrations(db)

    repo := postgresadapter.NewUserRepository(db)

    // Seed
    err = repo.Save(ctx, &domain.User{ID: "1", Email: "alice@example.com", Name: "Alice"})
    require.NoError(t, err)

    // Test
    user, err := repo.FindByEmail(ctx, "alice@example.com")
    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

Separate integration tests with a build tag so they don't run during fast unit test cycles:

```bash
# Unit tests only (fast)
go test ./...

# With integration tests
go test -tags=integration ./...
```

---

## Test Helpers and `testify`

Use `testify` for assertions — it produces readable failure messages.

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// assert — test continues after failure (good for checking multiple fields)
assert.Equal(t, "alice@example.com", user.Email)
assert.NoError(t, err)

// require — test stops immediately on failure (good for preconditions)
require.NoError(t, err)  // No point checking user.Email if err != nil
assert.Equal(t, "Alice", user.Name)
```

Use `require` for preconditions (if this fails, subsequent assertions are meaningless) and `assert` for the actual assertions.

---

## Test File Organization

- Test files live **alongside the code they test** (`user_service_test.go` next to `user_service.go`).
- Use `package xxx_test` (external test package) for testing the public API. Use `package xxx` (internal) only when you need to test unexported internals.
- Integration tests get a `//go:build integration` tag.

```
internal/users/domain/
├── service.go
├── service_test.go          # Unit tests — package domain_test
├── user.go
└── user_test.go

internal/users/adapters/postgres/
├── repository.go
└── repository_integration_test.go  # //go:build integration
```

---

## Anti-Patterns

### ❌ Testing implementation details
```go
// This test breaks every time the internal structure changes
// even if the behavior is still correct
assert.Equal(t, "queryUsers", svc.lastCalledMethod)
assert.Len(t, svc.cache.entries, 3)
```
Test behavior (inputs and outputs), not implementation (internal state and method calls).

### ❌ One giant test function
```go
func TestUserService(t *testing.T) {
    // 200 lines testing everything with nested if statements
    // Failure message: "TestUserService failed" — helpful.
}
```
Use table-driven tests and `t.Run()` so failures name the exact scenario.

### ❌ Mocking everything, including the domain
```go
// The domain service is mocked in the domain test
// So you're not testing any actual domain logic
mockSvc := mocks.NewUserService(t)
mockSvc.On("Register", ...).Return(...)
```
Domain tests should test real domain code with in-memory infrastructure, not mocks of the domain itself.

### ❌ Shared global state in tests
```go
var testDB *pgxpool.Pool  // Shared across all tests — they interfere with each other

func TestMain(m *testing.M) {
    testDB = connectDB()
    m.Run()
}
```
Use `testcontainers` to spin up a fresh DB per test suite, or wrap each test in a transaction that's rolled back after.

### ❌ Tests that depend on execution order
```go
func TestCreate(t *testing.T) { /* creates user with ID "1" */ }
func TestGet(t *testing.T) { /* assumes user "1" exists */ }
```
Each test must be fully self-contained. Use `t.Cleanup()` to tear down state.

---

[← Concurrency](./07-concurrency.md) | [Index](./README.md) | [Next: Data Access →](./09-data-access.md)
