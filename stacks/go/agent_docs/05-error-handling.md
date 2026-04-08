# 05 · Error Handling

Go's error handling is explicit by design. There is no exception system, no try/catch, no hidden control flow. Every error is a value that must be deliberately handled. This is a feature — it forces you to think about failure at every step.

---

## Always Wrap Errors With Context

When you return an error, add a layer of context that explains what your code was trying to do. This builds an error chain that reads like a story when it reaches the top.

```go
// ✅ Good — each layer adds context
func (s *Service) Register(ctx context.Context, email string) (*User, error) {
    user, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        return nil, fmt.Errorf("registering user: %w", err)
    }
    // ...
}

// Error chain reads: "registering user: querying by email: connection refused"
```

```go
// ❌ Bad — the error loses all context about where it came from
func (s *Service) Register(ctx context.Context, email string) (*User, error) {
    user, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        return nil, err  // Where did this error come from? No idea.
    }
    // ...
}
```

The `%w` verb (not `%v`) is critical — it wraps the error so `errors.Is` and `errors.As` can unwrap the chain.

---

## Sentinel Errors for Known Conditions

Sentinel errors are package-level error values that represent specific, expected failure conditions. They allow callers to check *what kind* of failure occurred.

```go
// internal/users/domain/errors.go
package domain

import "errors"

var (
    ErrUserNotFound  = errors.New("user not found")
    ErrEmailTaken    = errors.New("email already taken")
    ErrInvalidEmail  = errors.New("invalid email address")
)
```

```go
// Caller checks using errors.Is — works through the entire error chain
user, err := svc.GetByID(ctx, id)
if errors.Is(err, domain.ErrUserNotFound) {
    render(w, http.StatusNotFound, notFoundResponse())
    return
}
if err != nil {
    render(w, http.StatusInternalServerError, internalErrorResponse())
    return
}
```

---

## Custom Error Types for Rich Errors

When a caller needs more information than just "what went wrong" — for example, to know *which field* failed validation — use a custom error type.

```go
// internal/users/domain/errors.go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation failed on %s: %s", e.Field, e.Message)
}
```

```go
// Caller extracts the rich error with errors.As
var ve *domain.ValidationError
if errors.As(err, &ve) {
    render(w, http.StatusUnprocessableEntity, validationErrorResponse(ve.Field, ve.Message))
    return
}
```

---

## The Error Translation Boundary

Each architectural layer should translate errors from the layer below into its own language. Don't let infrastructure errors leak up to the domain, and don't let domain errors leak into HTTP responses without translation.

```
postgres driver error
    ↓  (postgres adapter translates to domain.ErrUserNotFound)
domain error
    ↓  (http adapter translates to 404 response)
HTTP response
```

```go
// ✅ The postgres adapter translates infrastructure errors to domain errors
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*domain.User, error) {
    err := r.db.QueryRow(ctx, query, email).Scan(...)
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, domain.ErrUserNotFound  // Translated to domain language
    }
    if err != nil {
        return nil, fmt.Errorf("querying user by email: %w", err)
    }
    return &user, nil
}
```

```go
// ✅ The HTTP adapter translates domain errors to HTTP status codes
func renderDomainError(w http.ResponseWriter, err error) {
    switch {
    case errors.Is(err, domain.ErrUserNotFound):
        render(w, http.StatusNotFound, errorBody("not_found", err.Error()))
    case errors.Is(err, domain.ErrEmailTaken):
        render(w, http.StatusConflict, errorBody("conflict", err.Error()))
    case errors.Is(err, domain.ErrInvalidEmail):
        render(w, http.StatusUnprocessableEntity, errorBody("validation_error", err.Error()))
    default:
        render(w, http.StatusInternalServerError, errorBody("internal_error", "an unexpected error occurred"))
    }
}
```

---

## Where to Log Errors

**Log once, at the boundary where you stop propagating.**

When you wrap and return an error, you're still propagating it — don't log it yet. When you've decided what to do with an error and stop propagating it, that's when you log.

```go
// ✅ Log at the boundary — the HTTP handler is where propagation stops
func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    user, err := h.svc.Register(r.Context(), req.Email, req.Name)
    if err != nil {
        slog.ErrorContext(r.Context(), "failed to register user", "error", err)
        renderDomainError(w, err)
        return
    }
    render(w, http.StatusCreated, toUserResponse(user))
}
```

```go
// ❌ Logging at every level creates noise and duplicate log entries
func (s *Service) Register(ctx context.Context, email string) (*User, error) {
    user, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        slog.Error("error finding user", "error", err)  // Logs once here
        return nil, fmt.Errorf("registering user: %w", err)
        // Then logs again at the handler level — duplicate
    }
    // ...
}
```

---

## Do Not Use `panic` for Business Logic

`panic` is for truly unrecoverable situations: programmer errors, violated invariants that should never happen. It is not a substitute for returning an error.

```go
// ✅ Return an error for expected failure conditions
func (s *Service) Register(ctx context.Context, email string) (*User, error) {
    if email == "" {
        return nil, domain.ErrInvalidEmail
    }
    // ...
}

// ❌ panic is not error handling
func (s *Service) Register(ctx context.Context, email string) *User {
    if email == "" {
        panic("email is required")
    }
    // ...
}
```

It is acceptable to use `panic` in `Must*` functions that are only called at startup:

```go
// Acceptable — called once at startup, failure is unrecoverable
func MustConnect(dsn string) *pgxpool.Pool {
    pool, err := pgxpool.New(context.Background(), dsn)
    if err != nil {
        panic(fmt.Sprintf("connecting to database: %v", err))
    }
    return pool
}
```

---

## Anti-Patterns

### ❌ Swallowing errors
```go
user, _ := s.repo.FindByEmail(ctx, email)  // If this fails, user is nil
                                            // and the next line will panic
fmt.Println(user.Email)
```
Every `_` on an error return is a place where silent failures can hide. Use `_` only when you have a documented, intentional reason.

### ❌ Comparing error strings
```go
if err.Error() == "user not found" {  // Brittle — breaks if the message ever changes
    // ...
}
```
**Fix:** Use sentinel errors and `errors.Is`.

### ❌ Wrapping with `%v` instead of `%w`
```go
return fmt.Errorf("registering user: %v", err)  // Loses the error chain
```
`%v` formats the error as a string, losing the ability to use `errors.Is` and `errors.As`. Always use `%w`.

### ❌ Logging and returning at every level
```go
func (r *Repository) FindByEmail(ctx context.Context, email string) (*User, error) {
    err := r.db.QueryRow(...)
    if err != nil {
        log.Error("db error", err)  // Logged here
        return nil, err
    }
}

func (s *Service) Register(ctx context.Context, email string) (*User, error) {
    _, err := s.repo.FindByEmail(ctx, email)
    if err != nil {
        log.Error("service error", err)  // Logged again
        return nil, err
    }
}
```
The same error appears in logs multiple times with different messages. Log once, at the boundary.

### ❌ Using `errors.New` for dynamic error messages
```go
return errors.New("user " + id + " not found")  // Can't be checked with errors.Is
```
For errors that carry data, use a custom error type. For sentinel errors, the message should be static.

---

[← Interface Design](./04-interface-design.md) | [Index](./README.md) | [Next: Dependency Injection →](./06-dependency-injection.md)
