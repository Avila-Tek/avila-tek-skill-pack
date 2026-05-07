# Go — Testing Reference

## Test Pyramid in a Hexagonal Codebase

```
         ┌──────┐
        /  e2e   \        Slow, few — full stack from HTTP to DB
       /──────────\
      / integration \     Medium — adapters against real infrastructure
     /──────────────\
    /   unit tests   \    Fast, many — domain logic with no infrastructure
   /──────────────────\
```

- **Domain tests** — no mocks, no databases, pure Go. Test all business rules here.
- **Adapter tests** — HTTP handlers with `httptest`, DB repos with `testcontainers`.
- **E2E tests** — full stack via HTTP. Few, for critical paths only.

## Table-Driven Tests

The idiomatic Go pattern. Reduces boilerplate, easy to add cases, documents expected behavior inline:

```go
func TestUserService_Register(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr error
    }{
        {"valid email registers", "alice@example.com", nil},
        {"empty email returns error", "", domain.ErrInvalidEmail},
        {"duplicate email returns conflict", "existing@example.com", domain.ErrEmailTaken},
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

## Domain Tests: In-Memory Repos (No Mocks)

Domain logic depends only on interfaces — use in-memory adapters, no mock framework needed:

```go
// internal/users/adapters/memory/repository.go
type UserRepository struct {
    mu    sync.RWMutex
    store map[string]*domain.User
}

func NewUserRepository() *UserRepository {
    return &UserRepository{store: make(map[string]*domain.User)}
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
    r.mu.RLock(); defer r.mu.RUnlock()
    for _, u := range r.store {
        if u.Email == email { return u, nil }
    }
    return nil, domain.ErrUserNotFound
}

func (r *UserRepository) Save(ctx context.Context, user *domain.User) error {
    r.mu.Lock(); defer r.mu.Unlock()
    r.store[user.ID] = user
    return nil
}
```

Domain tests are instant — no network, no disk. Maximum coverage here.

## HTTP Handler Tests with `httptest`

```go
func TestUserHandler_Register_Success(t *testing.T) {
    mockSvc := mocks.NewUserService(t)
    mockSvc.On("Register", mock.Anything, "alice@example.com", "Alice").
        Return(&domain.User{ID: "1", Email: "alice@example.com"}, nil)

    handler := httphandler.NewUserHandler(mockSvc)

    req := httptest.NewRequest(http.MethodPost, "/users", body(`{"email":"alice@example.com","name":"Alice"}`))
    req.Header.Set("Content-Type", "application/json")
    w := httptest.NewRecorder()

    handler.Routes().ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)
    mockSvc.AssertExpectations(t)
}
```

Generate mocks with `mockery`:
```bash
mockery --dir=internal/users/ports --output=internal/users/mocks --all
```

## DB Integration Tests with `testcontainers`

Use build tag `integration` to keep these out of fast unit test cycles:

```go
//go:build integration

func TestUserRepository_FindByEmail(t *testing.T) {
    ctx := context.Background()
    container, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
    )
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    dsn, _ := container.ConnectionString(ctx, "sslmode=disable")
    db := postgres.MustConnect(dsn)
    runMigrations(db)
    repo := postgresadapter.NewUserRepository(db)

    err = repo.Save(ctx, &domain.User{ID: "1", Email: "alice@example.com", Name: "Alice"})
    require.NoError(t, err)

    user, err := repo.FindByEmail(ctx, "alice@example.com")
    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

## Assertions: `testify`

```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// require — stops test immediately (use for preconditions)
require.NoError(t, err)         // no point checking user if err != nil

// assert — continues after failure (use for actual assertions)
assert.Equal(t, "alice@example.com", user.Email)
assert.NoError(t, err)
assert.ErrorIs(t, err, domain.ErrUserNotFound)
```

## File Organization

```
internal/users/domain/
├── service.go
├── service_test.go          # Unit — package domain_test
├── user.go
└── user_test.go

internal/users/adapters/postgres/
├── repository.go
└── repository_integration_test.go  # //go:build integration
```

Use `package xxx_test` (external) for public API tests. Use `package xxx` (internal) only when testing unexported internals.

## Commands

```bash
go test ./...                       # all unit tests
go test -tags=integration ./...     # include integration tests
go test -run TestUserService ./...  # single test
go test -race ./...                 # race condition detection
```

## Anti-Patterns

- One giant test function — use table-driven tests + `t.Run()` for named scenarios
- Mocking the domain — test real domain code with in-memory infrastructure
- Shared global `testDB` — use testcontainers per suite or transaction-per-test
- Tests that depend on execution order — each test must be fully self-contained
- Testing internal state instead of behavior — assert inputs/outputs, not method calls
