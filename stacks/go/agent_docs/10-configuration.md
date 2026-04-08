# 10 · Configuration

Configuration is the one place where the outside world (environment, infrastructure) shapes your application's behavior. The goal is to load it once, validate it completely, and make it available as typed Go values — never as raw strings scattered across the codebase.

---

## All Configuration From Environment Variables

Follow the [12-factor app](https://12factor.net/config) principle: all configuration comes from environment variables. This makes the application portable across environments (local, staging, production) without code changes.

```bash
# .env.example — committed to the repo as documentation
DATABASE_URL=postgres://user:pass@localhost:5432/myapp?sslmode=disable
REDIS_URL=redis://localhost:6379
HTTP_ADDR=:8080
LOG_LEVEL=info
JWT_SECRET=your-secret-here
```

Never commit `.env` — only `.env.example`.

---

## Parse Into a Typed Struct at Startup

Parse all environment variables once, at startup, into a strongly typed struct. Every field should be the right type — not `string` unless it genuinely is a string.

```go
// internal/config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

type Config struct {
    // Server
    HTTPAddr        string
    ReadTimeout     time.Duration
    WriteTimeout    time.Duration

    // Database
    DatabaseURL     string
    DBMaxConns      int32
    DBMinConns      int32

    // Redis
    RedisURL        string

    // Auth
    JWTSecret       string
    JWTExpiry       time.Duration

    // Observability
    LogLevel        string
    OTELEndpoint    string
    Environment     string
}

func Load() (*Config, error) {
    cfg := &Config{}
    var errs []string

    // Required fields — fail if missing
    cfg.DatabaseURL = requireEnv("DATABASE_URL", &errs)
    cfg.JWTSecret   = requireEnv("JWT_SECRET", &errs)

    // Optional with defaults
    cfg.HTTPAddr      = envOr("HTTP_ADDR", ":8080")
    cfg.LogLevel      = envOr("LOG_LEVEL", "info")
    cfg.Environment   = envOr("ENVIRONMENT", "development")
    cfg.OTELEndpoint  = os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") // empty = disabled

    // Typed fields
    cfg.DBMaxConns = int32(envInt("DB_MAX_CONNS", 25, &errs))
    cfg.DBMinConns = int32(envInt("DB_MIN_CONNS", 5, &errs))

    cfg.ReadTimeout  = envDuration("HTTP_READ_TIMEOUT", 5*time.Second, &errs)
    cfg.WriteTimeout = envDuration("HTTP_WRITE_TIMEOUT", 10*time.Second, &errs)
    cfg.JWTExpiry    = envDuration("JWT_EXPIRY", 24*time.Hour, &errs)

    if len(errs) > 0 {
        return nil, fmt.Errorf("invalid configuration:\n  - %s", strings.Join(errs, "\n  - "))
    }

    return cfg, nil
}

// MustLoad panics if config is invalid. Use in main() only.
func MustLoad() *Config {
    cfg, err := Load()
    if err != nil {
        panic(err)
    }
    return cfg
}
```

```go
// Helper functions
func requireEnv(key string, errs *[]string) string {
    v := os.Getenv(key)
    if v == "" {
        *errs = append(*errs, fmt.Sprintf("%s is required", key))
    }
    return v
}

func envOr(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}

func envInt(key string, fallback int, errs *[]string) int {
    v := os.Getenv(key)
    if v == "" {
        return fallback
    }
    n, err := strconv.Atoi(v)
    if err != nil {
        *errs = append(*errs, fmt.Sprintf("%s must be an integer, got %q", key, v))
        return fallback
    }
    return n
}

func envDuration(key string, fallback time.Duration, errs *[]string) time.Duration {
    v := os.Getenv(key)
    if v == "" {
        return fallback
    }
    d, err := time.ParseDuration(v)
    if err != nil {
        *errs = append(*errs, fmt.Sprintf("%s must be a valid duration (e.g. 5s, 1m), got %q", key, v))
        return fallback
    }
    return d
}
```

---

## Fail Fast if Configuration is Invalid

If required configuration is missing or malformed, **the application must refuse to start**. A clear error at startup is infinitely better than a confusing failure five minutes into production traffic.

```go
// cmd/api/main.go
func main() {
    cfg, err := config.Load()
    if err != nil {
        // Print the full error to stderr and exit immediately
        fmt.Fprintf(os.Stderr, "configuration error:\n%v\n", err)
        os.Exit(1)
    }

    // From here on, cfg is fully valid and ready to use
    db := postgres.MustConnect(cfg.DatabaseURL)
    // ...
}
```

Example output when misconfigured:
```
configuration error:
invalid configuration:
  - DATABASE_URL is required
  - JWT_SECRET is required
  - DB_MAX_CONNS must be an integer, got "twenty-five"
```

---

## Never Read `os.Getenv` Deep in the Stack

Environment variables are read **once** at startup. Code deep in the call stack (domain services, repositories, handlers) never calls `os.Getenv` — it receives config values through constructors.

```go
// ✅ Config value passed through constructor
func NewMailer(cfg config.SMTPConfig) *Mailer {
    return &Mailer{
        host: cfg.Host,
        port: cfg.Port,
    }
}

// ❌ Reading env vars in a service — invisible dependency, untestable
func (m *Mailer) Send(ctx context.Context, to, body string) error {
    host := os.Getenv("SMTP_HOST")  // Hidden dependency
    // ...
}
```

---

## Secrets

Secrets (database passwords, API keys, JWT secrets) come from environment variables in all environments. In production, use a secrets manager (AWS Secrets Manager, GCP Secret Manager, Vault) and inject values as environment variables at deploy time — never hardcode or commit them.

The `config.Config` struct holds the resolved values, not the mechanism for fetching them. The infrastructure that runs the service is responsible for providing them.

---

## Anti-Patterns

### ❌ Reading `os.Getenv` anywhere outside `config/`
```go
// internal/users/adapters/smtp/mailer.go
func (m *Mailer) Send(ctx context.Context, msg Message) error {
    host := os.Getenv("SMTP_HOST")  // ❌ Hidden, untestable dependency
    // ...
}
```

### ❌ Hardcoded defaults that hide misconfiguration
```go
func envOr(key, fallback string) string {
    if v := os.Getenv(key); v != "" {
        return v
    }
    return fallback
}

// Using empty string as a valid fallback for a required field
cfg.DatabaseURL = envOr("DATABASE_URL", "")  // ❌ Will fail later with a confusing error
```
If a field is required, use `requireEnv` and fail fast. Don't let missing config produce mysterious downstream failures.

### ❌ Config spread across multiple packages
```go
// pkg/db/db.go
var dbURL = os.Getenv("DATABASE_URL")

// pkg/auth/auth.go
var secret = os.Getenv("JWT_SECRET")

// pkg/mailer/mailer.go
var smtpHost = os.Getenv("SMTP_HOST")
```
All configuration parsing is centralized in `internal/config`. No other package reads environment variables directly.

### ❌ Passing raw config struct to every layer
```go
// Leaking the entire config into the domain layer
func NewUserService(cfg *config.Config, ...) *UserService { ... }
```
Domain services should receive specific values they need (e.g., `jwtExpiry time.Duration`), not a reference to the entire config struct. This avoids coupling the domain to the config structure.

---

[← Data Access](./09-data-access.md) | [Index](./README.md) | [Next: Observability →](./11-observability.md)
