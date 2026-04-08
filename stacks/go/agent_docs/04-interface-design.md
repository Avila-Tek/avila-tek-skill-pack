# 04 · Interface Design

Go's interfaces are implicit and structural — a type satisfies an interface simply by implementing its methods, with no declaration required. This is one of Go's most powerful features, and also one of its most misused.

---

## Keep Interfaces Small

The standard library sets the example: `io.Reader` has one method. `io.Writer` has one method. `io.Closer` has one method. You compose them when you need more.

**A good interface describes a single capability, not a whole object.**

```go
// ✅ Focused — each interface has one job
type UserFinder interface {
    FindByID(ctx context.Context, id string) (*User, error)
}

type UserSaver interface {
    Save(ctx context.Context, user *User) error
}

// Compose when you need both
type UserRepository interface {
    UserFinder
    UserSaver
}
```

```go
// ❌ Bloated — a new concrete type must implement 10 methods just to satisfy this
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    FindByEmail(ctx context.Context, email string) (*User, error)
    FindAll(ctx context.Context, filter UserFilter) ([]*User, error)
    Save(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
    Count(ctx context.Context) (int, error)
    Exists(ctx context.Context, id string) (bool, error)
    FindByOrg(ctx context.Context, orgID string) ([]*User, error)
    Archive(ctx context.Context, id string) error
}
```
When a test only needs `FindByID`, it still has to implement all 10 methods. When a new developer wants to understand what a function needs, they have to read a 10-method interface instead of a 1-method one.

---

## Define Interfaces Where They're Consumed, Not Where They're Implemented

This is the most important and most violated rule in Go interface design.

```go
// ✅ The HTTP handler defines the interface it needs — in its own package
// internal/users/adapters/http/handler.go
package http

type userService interface {
    Register(ctx context.Context, email, name string) (*domain.User, error)
    GetByID(ctx context.Context, id string) (*domain.User, error)
}

type Handler struct {
    svc userService
}
```

```go
// ❌ The interface is defined in the implementation package
// internal/users/adapters/postgres/repository.go
package postgres

// Why does the postgres package define this? It forces the http handler
// to import the postgres package just to get the interface type.
type UserRepository interface { ... }
```

When the interface lives at the consumer, you can have:
- Different consumers with different interface shapes (a handler that only needs `FindByID`, a background job that only needs `Save`).
- Zero coupling between packages — the postgres package has no idea the http package exists.
- Easy mocking in tests — generate a mock for the interface your package actually needs.

---

## Accept Interfaces, Return Structs

Functions that accept interfaces are flexible — any type satisfying the interface can be passed. Functions that return concrete structs are predictable — the caller gets full access to all methods and fields without needing a type assertion.

```go
// ✅ Accept interface, return struct
func NewUserService(repo UserRepository, cache UserCache) *UserService {
    return &UserService{repo: repo, cache: cache}
}
```

```go
// ❌ Returning an interface forces callers to type-assert to access
//    methods not on the interface, and hides what they actually get
func NewUserService(repo UserRepository) UserService {
    return &userServiceImpl{...}
}
```

Exception: returning an interface is appropriate when you deliberately want to hide the concrete type (e.g., a factory that can return different implementations). This should be rare.

---

## Interfaces Enable Testability

Because you define interfaces at the consumer, every dependency can be replaced with a mock in tests — without any changes to the production code.

```go
// The domain service depends on an interface
type Service struct {
    repo UserRepository
}

// In tests, pass an in-memory implementation
func TestService_Register_EmailAlreadyTaken(t *testing.T) {
    repo := memory.NewUserRepository()
    repo.Seed(&domain.User{Email: "existing@example.com"})

    svc := domain.NewService(repo)
    _, err := svc.Register(ctx, "existing@example.com", "Alice")

    assert.ErrorIs(t, err, domain.ErrEmailTaken)
}
```

No mocking framework needed for domain tests — just pass the in-memory adapter.

---

## Embedding for Composition

Use interface embedding to compose larger interfaces from smaller ones:

```go
type Reader interface {
    Read(ctx context.Context, id string) (*User, error)
}

type Writer interface {
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

// ReadWriter is only used where both capabilities are needed
type ReadWriter interface {
    Reader
    Writer
}
```

Functions that only need reading accept `Reader`. Functions that need both accept `ReadWriter`. This makes dependencies explicit and minimal.

---

## When NOT to Use an Interface

Interfaces add indirection. Don't create one unless you have a clear reason:

| Good reason for an interface | Not a good reason |
|------------------------------|-------------------|
| You have (or expect) multiple implementations | "It might be useful someday" |
| You need to mock it in tests | It's a concrete type with one implementation that won't change |
| You want to decouple two packages | You're following a pattern from Java/C# where everything is an interface |
| You want to expose a subset of a type's capabilities | The type is already simple |

A `UserService` struct with no alternative implementations does not need a `UserService` interface — until your HTTP handler needs to be tested without a real database, at which point you define a narrow interface at the handler.

---

## Anti-Patterns

### ❌ Interface defined alongside its only implementation
```go
// internal/users/domain/service.go
type UserService interface {   // Only one implementation exists and will ever exist
    Register(...)
    GetByID(...)
}

type userServiceImpl struct { ... }
func (s *userServiceImpl) Register(...) { ... }
```
You've added an interface for no reason. This pattern comes from Java habits. In Go, define the interface where it's consumed.

### ❌ The "everything is an interface" anti-pattern
```go
type Config interface { GetDatabaseURL() string }
type Logger interface { Log(msg string) }
type Clock interface { Now() time.Time }
```
If these types have one implementation and you never mock them in tests, these interfaces provide no value. Add them when you need them, not speculatively.

### ❌ Large interfaces used as function parameters
```go
// The function only uses FindByID, but now callers must satisfy all 10 methods
func DoSomething(repo UserRepository) error {
    user, err := repo.FindByID(ctx, "123")
    ...
}
```
**Fix:** Accept only what you need: `func DoSomething(finder UserFinder) error`.

### ❌ Returning interfaces to "hide" implementation
```go
func NewCache() CacheInterface {
    return &redisCache{}
}
```
Now the caller has to type-assert to access Redis-specific methods. If you want to hide the implementation, the package boundary already does that. Return the concrete `*RedisCache` and let the caller's interface (defined at the consumer) provide the abstraction.

---

[← Architecture](./03-architecture.md) | [Index](./README.md) | [Next: Error Handling →](./05-error-handling.md)
