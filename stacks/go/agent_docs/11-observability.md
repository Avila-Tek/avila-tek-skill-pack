# 11 · Observability

Observability means being able to understand what your system is doing from the outside — when it's healthy, when something is wrong, and why. It has three pillars: **logs**, **metrics**, and **traces**. All three should be built in from the start, not bolted on later.

---

## Structured Logging with `slog`

Use Go's standard library [`slog`](https://pkg.go.dev/log/slog) (available since Go 1.21) for all logging. Structured logs (key-value pairs) are machine-readable and can be queried in any log aggregation system.

```go
// ✅ Structured — queryable, consistent
slog.InfoContext(ctx, "user registered", "user_id", user.ID, "email", user.Email)
slog.ErrorContext(ctx, "failed to send welcome email", "user_id", user.ID, "error", err)

// ❌ Unstructured — can't be queried or parsed reliably
log.Printf("user registered: %s (%s)", user.ID, user.Email)
fmt.Println("error:", err)
```

---

## Logger Setup

Initialize the logger once at startup with the appropriate format and level. In development, use a human-readable format. In production, use JSON.

```go
// internal/logger/logger.go
package logger

import (
    "log/slog"
    "os"
)

func New(level, environment string) *slog.Logger {
    var lvl slog.Level
    if err := lvl.UnmarshalText([]byte(level)); err != nil {
        lvl = slog.LevelInfo
    }

    opts := &slog.HandlerOptions{Level: lvl}

    var handler slog.Handler
    if environment == "production" {
        handler = slog.NewJSONHandler(os.Stdout, opts)
    } else {
        handler = slog.NewTextHandler(os.Stdout, opts)
    }

    return slog.New(handler)
}
```

Pass the logger via constructor — never use a global logger.

```go
// ✅ Logger via constructor
type UserService struct {
    repo   ports.UserRepository
    logger *slog.Logger
}

func NewUserService(repo ports.UserRepository, logger *slog.Logger) *UserService {
    return &UserService{repo: repo, logger: logger.With("component", "user_service")}
}
```

The `.With("component", "user_service")` call creates a child logger that automatically attaches `component=user_service` to every log line from this service.

---

## Always Log With Context

`slog.InfoContext(ctx, ...)` instead of `slog.Info(...)` — this allows middleware to inject request-scoped fields (trace IDs, request IDs) that automatically appear in all log lines for that request.

```go
// Middleware attaches request-scoped fields to context
func RequestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            requestID := r.Header.Get("X-Request-ID")
            if requestID == "" {
                requestID = uuid.NewString()
            }

            ctx := slogctx.NewContext(r.Context(), logger.With(
                "request_id", requestID,
                "method", r.Method,
                "path", r.URL.Path,
            ))

            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// Deep in the call stack, logs automatically include request_id
func (s *UserService) Register(ctx context.Context, email string) (*User, error) {
    s.logger.InfoContext(ctx, "registering user", "email", email)
    // Log line: level=INFO msg="registering user" component=user_service request_id=abc123 email=alice@example.com
}
```

---

## Log Levels

| Level | When to use |
|-------|-------------|
| `DEBUG` | Detailed diagnostic info, disabled in production |
| `INFO` | Normal operations — a request succeeded, a job completed |
| `WARN` | Something unexpected but recoverable — a retry succeeded, a deprecated API was used |
| `ERROR` | Something failed that requires attention — unhandled error, downstream unavailable |

Never log at ERROR for expected domain errors (user not found, email taken). Those are normal. Log at ERROR only for unexpected infrastructure or programming failures.

---

## Prometheus Metrics

Use [prometheus/client_golang](https://github.com/prometheus/client_golang) to expose metrics. Define metrics at the package level and register them at startup.

```go
// internal/users/adapters/http/metrics.go
package http

import "github.com/prometheus/client_golang/prometheus"

var (
    requestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(requestsTotal, requestDuration)
}
```

Expose the `/metrics` endpoint in your router:

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

r.Handle("/metrics", promhttp.Handler())
```

For HTTP metrics, use a middleware rather than instrumenting each handler:

```go
func PrometheusMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}

        next.ServeHTTP(rw, r)

        duration := time.Since(start).Seconds()
        status := strconv.Itoa(rw.status)

        requestsTotal.WithLabelValues(r.Method, r.URL.Path, status).Inc()
        requestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
    })
}
```

---

## OpenTelemetry for Distributed Tracing

Use [OpenTelemetry](https://opentelemetry.io/docs/languages/go/) to instrument the application for distributed tracing. Add spans at boundaries — HTTP handlers and external I/O.

```go
// Initialize the tracer provider at startup
func initTracer(endpoint string) (func(), error) {
    exporter, err := otlptracehttp.New(context.Background(),
        otlptracehttp.WithEndpoint(endpoint),
    )
    if err != nil {
        return nil, err
    }

    provider := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceName("my-api"),
        )),
    )

    otel.SetTracerProvider(provider)

    return func() { provider.Shutdown(context.Background()) }, nil
}
```

```go
// Add spans at service boundaries
func (s *UserService) Register(ctx context.Context, email, name string) (*User, error) {
    ctx, span := otel.Tracer("user-service").Start(ctx, "UserService.Register")
    defer span.End()

    span.SetAttributes(attribute.String("user.email", email))

    user, err := s.repo.Save(ctx, email, name)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return nil, err
    }

    return user, nil
}
```

---

## Health Check Endpoints

Expose two health endpoints — essential for orchestrators like Kubernetes:

```go
// /healthz — liveness: is the process alive?
r.Get("/healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("ok"))
})

// /readyz — readiness: is the service ready to serve traffic?
r.Get("/readyz", func(w http.ResponseWriter, r *http.Request) {
    if err := db.Ping(r.Context()); err != nil {
        http.Error(w, "database unavailable", http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
    w.Write([]byte("ok"))
})
```

- **Liveness** (`/healthz`): Returns 200 if the process is running. Kubernetes restarts the pod if this fails.
- **Readiness** (`/readyz`): Returns 200 only if the service can handle traffic (DB connected, migrations run, etc.). Kubernetes removes the pod from the load balancer if this fails.

---

## Anti-Patterns

### ❌ `fmt.Println` or `log.Println` in production code
```go
fmt.Println("starting server...")
log.Printf("user %s registered", userID)
```
Unstructured, can't be queried. Use `slog`.

### ❌ Global logger
```go
var logger = slog.Default()  // Package-level — can't be customized per test or per service
```

### ❌ Logging sensitive data
```go
slog.Info("user login", "email", email, "password", password)  // ❌ Never log passwords
slog.Info("payment processed", "card_number", card)           // ❌ Never log PII or secrets
```

### ❌ Logging errors at every level (log and return)
```go
func (r *repo) FindByID(ctx, id) (*User, error) {
    err := r.db.QueryRow(...)
    if err != nil {
        slog.Error("db error", "error", err)  // Logs once
        return nil, err  // Then logs again at the handler
    }
}
```
Log once, at the boundary where you stop propagating. See [Error Handling](./05-error-handling.md).

### ❌ Using `panic` to surface observability setup failures
```go
func initTracer() {
    // If OTEL setup fails, the whole app crashes even though
    // the app can run without tracing
}
```
Observability infrastructure failures should be logged and tolerated where possible, not fatal (except at startup validation).

---

[← Configuration](./10-configuration.md) | [Index](./README.md) | [Next: HTTP Layer →](./12-http-layer.md)
