# 06 · Dependency Injection

Dependency injection in Go doesn't need a framework. The language's constructor functions and explicit wiring in `main.go` are the idiomatic approach — and they make the dependency graph readable at a glance without any magic.

---

## The Constructor Pattern

Every type with dependencies uses a constructor function that accepts those dependencies as arguments. No global state, no service locator, no auto-wiring.

```go
// ✅ Constructor function — dependencies are explicit
type UserService struct {
    repo  ports.UserRepository
    cache ports.UserCache
    mailer ports.Mailer
}

func NewUserService(
    repo ports.UserRepository,
    cache ports.UserCache,
    mailer ports.Mailer,
) *UserService {
    return &UserService{
        repo:   repo,
        cache:  cache,
        mailer: mailer,
    }
}
```

Every dependency is:
- **Visible** — you can see what a type needs by reading its constructor.
- **Replaceable** — pass a different implementation (e.g., an in-memory mock in tests).
- **Testable** — inject exactly what the test needs, nothing more.

---

## Wiring in `cmd/`

All wiring happens once, in `main.go`. The wiring order follows the dependency graph: construct the innermost dependencies first, then compose them outward.

```go
// cmd/api/main.go
func main() {
    // 1. Load configuration
    cfg := config.MustLoad()

    // 2. Infrastructure
    db      := postgres.MustConnect(cfg.DatabaseURL)
    redisDB := redis.MustConnect(cfg.RedisURL)

    // 3. Adapters (infrastructure implementations)
    userRepo   := postgresadapter.NewUserRepository(db)
    userCache  := redisadapter.NewUserCache(redisDB)
    mailer     := smtpadapter.NewMailer(cfg.SMTPConfig)

    // 4. Domain services
    userSvc := users.NewService(userRepo, userCache, mailer)

    // 5. HTTP handlers
    userHandler := httphandler.NewUserHandler(userSvc)

    // 6. Router
    r := chi.NewRouter()
    r.Use(middleware.Logger, middleware.Recoverer)
    r.Mount("/v1/users", userHandler.Routes())

    // 7. Start
    srv := &http.Server{Addr: cfg.Addr, Handler: r}
    log.Fatal(srv.ListenAndServe())
}
```

This file is the map of your entire application. Anyone can read it and understand how all the pieces connect.

---

## Functional Options for Optional Configuration

When a constructor has many optional parameters (timeouts, retry counts, feature flags), use the functional options pattern instead of config structs or long parameter lists.

```go
type UserService struct {
    repo    ports.UserRepository
    timeout time.Duration
    retries int
}

type Option func(*UserService)

func WithTimeout(d time.Duration) Option {
    return func(s *UserService) {
        s.timeout = d
    }
}

func WithRetries(n int) Option {
    return func(s *UserService) {
        s.retries = n
    }
}

func NewUserService(repo ports.UserRepository, opts ...Option) *UserService {
    svc := &UserService{
        repo:    repo,
        timeout: 5 * time.Second, // sensible defaults
        retries: 3,
    }
    for _, opt := range opts {
        opt(svc)
    }
    return svc
}

// Usage
svc := users.NewUserService(repo,
    users.WithTimeout(10*time.Second),
    users.WithRetries(5),
)
```

This keeps the constructor signature stable as options are added or removed.

---

## No Global State

Global mutable state is the enemy of testability and predictability. Avoid it.

```go
// ❌ Global state — anyone can modify this, tests interfere with each other
var defaultDB *pgxpool.Pool

func init() {
    defaultDB = connectDB()
}

func GetUser(id string) (*User, error) {
    return queryUser(defaultDB, id)
}
```

```go
// ✅ Explicit dependencies — each test gets its own DB connection
type UserRepository struct {
    db *pgxpool.Pool
}

func NewUserRepository(db *pgxpool.Pool) *UserRepository {
    return &UserRepository{db: db}
}
```

**The `init()` function is banned for setup.** `init()` runs automatically, in an undefined order, and can't be disabled in tests. Use explicit initialization in `main.go` instead.

The only acceptable uses of `init()` are registering drivers or codecs where the registration pattern is forced by a third-party library (e.g., `_ "github.com/lib/pq"`).

---

## No Package-Level Variables for Dependencies

Package-level variables for dependencies (loggers, DB connections, config) create hidden coupling and make tests unpredictable.

```go
// ❌ Package-level logger — test output interleaved, can't be customized per test
var logger = slog.Default()

func RegisterUser(ctx context.Context, email string) error {
    logger.Info("registering user", "email", email)
    // ...
}
```

```go
// ✅ Logger passed via constructor or context
type UserService struct {
    repo   ports.UserRepository
    logger *slog.Logger
}

func NewUserService(repo ports.UserRepository, logger *slog.Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}
```

---

## Google Wire (Optional)

For large services where manual wiring in `main.go` grows unwieldy (50+ lines of wiring), [Wire](https://github.com/google/wire) can generate the wiring code from provider functions. It is entirely optional — the generated code is plain Go, readable, and doesn't require the Wire binary at runtime.

```go
// wire.go (only used during code generation)
//go:build wireinject

func InitializeAPI(cfg *config.Config) (*chi.Mux, error) {
    wire.Build(
        postgres.NewPool,
        postgresadapter.NewUserRepository,
        users.NewService,
        httphandler.NewUserHandler,
        newRouter,
    )
    return nil, nil
}
```

Wire generates `wire_gen.go` with the explicit constructor calls — identical to what you'd write by hand.

Only reach for Wire if manual wiring is genuinely painful. Most services don't need it.

---

## Anti-Patterns

### ❌ Service Locator
```go
// A global registry that everything calls to get its dependencies
container := di.NewContainer()
container.Register("userRepo", postgres.NewUserRepository)

// Somewhere deep in business logic
repo := container.Get("userRepo").(ports.UserRepository)
```
Dependencies are hidden. You can't tell what a function needs by reading it. Tests require setting up the entire container.

### ❌ Singleton via `sync.Once`
```go
var (
    once   sync.Once
    dbPool *pgxpool.Pool
)

func GetDB() *pgxpool.Pool {
    once.Do(func() {
        dbPool = connectDB()
    })
    return dbPool
}
```
This is global state with extra steps. Tests share the same DB pool, can't be parallelized safely, and the initialization is invisible to callers.

### ❌ `init()` for application setup
```go
func init() {
    db = connectToDB(os.Getenv("DATABASE_URL"))
    cache = connectToRedis(os.Getenv("REDIS_URL"))
    mailer = newSMTPMailer()
}
```
`init()` runs before `main()`, before you've had a chance to load config, set up logging, or handle errors gracefully. Failures in `init()` produce opaque panics.

### ❌ Constructors that do I/O
```go
func NewUserService(dsn string) *UserService {
    db, err := pgxpool.New(context.Background(), dsn) // ❌ I/O in constructor
    if err != nil {
        panic(err)
    }
    return &UserService{db: db}
}
```
Constructors should be pure — accept already-initialized dependencies, not raw config strings. Infrastructure initialization belongs in `main.go`.

---

[← Error Handling](./05-error-handling.md) | [Index](./README.md) | [Next: Concurrency →](./07-concurrency.md)
