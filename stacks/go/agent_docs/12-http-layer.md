# 12 · HTTP Layer

The HTTP layer is an adapter — its job is to translate HTTP requests into domain calls and domain results into HTTP responses. Business logic never lives here. The thinner the handler, the better.

---

## Router: Chi (Primary) / Gin (Alternative)

### Chi — Preferred

[Chi](https://github.com/go-chi/chi) is the preferred router. It is stdlib-compatible (uses `net/http` handlers natively), lightweight, composable, and has excellent middleware support.

```go
import "github.com/go-chi/chi/v5"
import "github.com/go-chi/chi/v5/middleware"

func NewRouter(userHandler *httphandler.UserHandler, cfg *config.Config) http.Handler {
    r := chi.NewRouter()

    // Global middleware — applied to all routes
    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(RequestLogger(logger))
    r.Use(middleware.Recoverer)
    r.Use(middleware.Timeout(30 * time.Second))

    // Health checks — no auth
    r.Get("/healthz", healthz)
    r.Get("/readyz", readyz(db))

    // Metrics — no auth
    r.Handle("/metrics", promhttp.Handler())

    // Versioned API routes
    r.Route("/v1", func(r chi.Router) {
        r.Use(AuthMiddleware(cfg.JWTSecret))  // Auth applied to all /v1 routes

        r.Mount("/users", userHandler.Routes())
        r.Mount("/orders", orderHandler.Routes())
    })

    return r
}
```

### Gin — Alternative

[Gin](https://github.com/gin-gonic/gin) is an alternative with built-in JSON binding and a slightly more ergonomic API. Use it when your team prefers its conventions. The architectural patterns (thin handlers, DTOs, error translation) remain identical.

```go
import "github.com/gin-gonic/gin"

func NewRouter(userHandler *httphandler.UserHandler) *gin.Engine {
    r := gin.New()
    r.Use(gin.Recovery())
    r.Use(RequestLogger(logger))

    v1 := r.Group("/v1")
    v1.Use(AuthMiddleware(cfg.JWTSecret))

    userHandler.RegisterRoutes(v1.Group("/users"))

    return r
}
```

---

## Handler Design: Thin Handlers

A handler has three responsibilities:
1. Decode and validate the request
2. Call the domain service
3. Encode and send the response

```go
// internal/users/adapters/http/handler.go
package http

type Handler struct {
    svc userService  // unexported interface — defined here, not in ports
}

type userService interface {
    Register(ctx context.Context, email, name string) (*domain.User, error)
    GetByID(ctx context.Context, id string) (*domain.User, error)
}

func NewHandler(svc userService) *Handler {
    return &Handler{svc: svc}
}

func (h *Handler) Routes() chi.Router {
    r := chi.NewRouter()
    r.Post("/", h.register)
    r.Get("/{id}", h.getByID)
    return r
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    // 1. Decode
    var req RegisterRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        renderError(w, http.StatusBadRequest, "invalid_request", "could not parse request body")
        return
    }

    // 2. Validate
    if err := req.Validate(); err != nil {
        renderError(w, http.StatusUnprocessableEntity, "validation_error", err.Error())
        return
    }

    // 3. Call domain
    user, err := h.svc.Register(r.Context(), req.Email, req.Name)
    if err != nil {
        renderDomainError(w, err)
        return
    }

    // 4. Respond
    render(w, http.StatusCreated, toUserResponse(user))
}
```

---

## Request and Response DTOs

Domain types are never serialized directly to/from JSON. Use dedicated DTO structs in the HTTP adapter.

```go
// internal/users/adapters/http/dto.go

// --- Request DTOs ---

type RegisterRequest struct {
    Email string `json:"email"`
    Name  string `json:"name"`
}

func (r RegisterRequest) Validate() error {
    if r.Email == "" {
        return errors.New("email is required")
    }
    if !isValidEmail(r.Email) {
        return errors.New("email is not valid")
    }
    if r.Name == "" {
        return errors.New("name is required")
    }
    return nil
}

// --- Response DTOs ---

type UserResponse struct {
    ID        string    `json:"id"`
    Email     string    `json:"email"`
    Name      string    `json:"name"`
    CreatedAt time.Time `json:"created_at"`
}

func toUserResponse(u *domain.User) UserResponse {
    return UserResponse{
        ID:        u.ID,
        Email:     u.Email,
        Name:      u.Name,
        CreatedAt: u.CreatedAt,
    }
}
```

**Why separate DTOs?**
- The API contract can evolve independently of the domain model.
- Sensitive fields (e.g., password hashes, internal IDs) are never accidentally exposed.
- Validation lives with the DTO, not the domain.

---

## Consistent Error Responses

All error responses follow the same JSON structure across all endpoints:

```go
// internal/shared/httputil/render.go
type ErrorResponse struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

func renderError(w http.ResponseWriter, status int, code, message string) {
    render(w, status, ErrorResponse{Code: code, Message: message})
}

func render(w http.ResponseWriter, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(v)
}
```

Translate domain errors to HTTP responses in one place per handler (or a shared helper):

```go
// internal/users/adapters/http/errors.go
func renderDomainError(w http.ResponseWriter, err error) {
    switch {
    case errors.Is(err, domain.ErrUserNotFound):
        renderError(w, http.StatusNotFound, "not_found", "user not found")
    case errors.Is(err, domain.ErrEmailTaken):
        renderError(w, http.StatusConflict, "conflict", "email is already in use")
    case errors.Is(err, domain.ErrInvalidEmail):
        renderError(w, http.StatusUnprocessableEntity, "validation_error", err.Error())
    default:
        slog.ErrorContext(context.Background(), "unhandled domain error", "error", err)
        renderError(w, http.StatusInternalServerError, "internal_error", "an unexpected error occurred")
    }
}
```

---

## Middleware

Middleware wraps every request. Order matters: middleware applied first runs outermost (executes first on request, last on response).

**Standard middleware stack:**

```go
r.Use(middleware.RequestID)      // Assigns a unique ID to each request
r.Use(middleware.RealIP)         // Extracts real IP from X-Forwarded-For
r.Use(RequestLogger(logger))     // Logs every request with timing
r.Use(PrometheusMiddleware)      // Records request metrics
r.Use(middleware.Recoverer)      // Recovers from panics, returns 500
r.Use(middleware.Timeout(30*time.Second)) // Request timeout
```

Writing a middleware with Chi:

```go
func AuthMiddleware(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            token := r.Header.Get("Authorization")
            if token == "" {
                renderError(w, http.StatusUnauthorized, "unauthorized", "missing authorization header")
                return
            }

            claims, err := parseJWT(token, secret)
            if err != nil {
                renderError(w, http.StatusUnauthorized, "unauthorized", "invalid token")
                return
            }

            // Inject claims into context for downstream handlers
            ctx := context.WithValue(r.Context(), claimsKey, claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

---

## URL Parameters and Query Strings

```go
// chi URL parameters
func (h *Handler) getByID(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
    // ...
}

// Query string parameters
func (h *Handler) list(w http.ResponseWriter, r *http.Request) {
    page, _ := strconv.Atoi(r.URL.Query().Get("page"))
    if page < 1 {
        page = 1
    }
    limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
    if limit < 1 || limit > 100 {
        limit = 20
    }
    // ...
}
```

---

## Anti-Patterns

### ❌ Business logic in handlers
```go
func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    // Querying the DB directly from a handler bypasses the domain
    existing, _ := h.db.QueryRow("SELECT id FROM users WHERE email = $1", req.Email)
    if existing != nil {
        http.Error(w, "email taken", 409)
        return
    }
    h.db.Exec("INSERT INTO users ...")
}
```

### ❌ Domain models in responses
```go
// Exposes internal fields, tight coupling between API and domain
json.NewEncoder(w).Encode(user)  // user is *domain.User
```

### ❌ Fat routes file with all handlers inline
```go
// cmd/api/main.go
r.Post("/users", func(w http.ResponseWriter, r *http.Request) {
    // 50 lines of logic inline
})
r.Get("/users/{id}", func(w http.ResponseWriter, r *http.Request) {
    // ...
})
```

### ❌ Inconsistent error format
```go
// Handler A returns {"error": "not found"}
// Handler B returns {"message": "User not found", "status": 404}
// Handler C returns just a string: "error"
```
Every client has to handle every format. Use one error structure across the entire API.

### ❌ No request timeout
```go
// Without a timeout, a slow downstream makes requests pile up forever
r := chi.NewRouter()
// No middleware.Timeout — a slow DB query holds the goroutine indefinitely
```

---

[← Observability](./11-observability.md) | [Index](./README.md) | [Next: Tooling →](./13-tooling.md)
