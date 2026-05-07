# Go — Security Reference (OWASP Top 10)

## A01 · Broken Access Control

Authentication middleware at the router level — never per-handler:

```go
// ✅ Auth applied once at the route group level
r.Route("/v1", func(r chi.Router) {
    r.Use(AuthMiddleware(cfg.JWTSecret)) // all /v1/* routes require auth
    r.Mount("/users", userHandler.Routes())
    r.Mount("/orders", orderHandler.Routes())
})

// Public routes outside the authenticated group
r.Get("/healthz", healthz)
r.Post("/auth/login", authHandler.Login)
```

Resource ownership — always verify the caller owns the resource before allowing mutation:

```go
func (h *Handler) updateOrder(w http.ResponseWriter, r *http.Request) {
    orderID := chi.URLParam(r, "id")
    callerID := auth.UserIDFromContext(r.Context())

    order, err := h.svc.GetOrder(r.Context(), orderID)
    if errors.Is(err, domain.ErrOrderNotFound) {
        renderError(w, http.StatusNotFound, "not_found", "order not found")
        return
    }
    if order.OwnerID != callerID {
        renderError(w, http.StatusForbidden, "forbidden", "access denied")
        return
    }
    // proceed
}
```

## A02 · Cryptographic Failures

Passwords hashed with bcrypt (cost ≥ 12):

```go
import "golang.org/x/crypto/bcrypt"

const bcryptCost = 12

func hashPassword(plain string) (string, error) {
    hashed, err := bcrypt.GenerateFromPassword([]byte(plain), bcryptCost)
    return string(hashed), err
}

func verifyPassword(plain, hashed string) bool {
    return bcrypt.CompareHashAndPassword([]byte(hashed), []byte(plain)) == nil
}
```

Secrets from environment — never hardcoded:

```go
// ✅ Via config struct bound to env vars
type Config struct {
    JWTSecret   string `env:"JWT_SECRET,required"`
    DatabaseURL string `env:"DATABASE_URL,required"`
}

// ❌ Never
jwtSecret := "super-secret-key"
```

JWT tokens: short expiry (≤ 15 min for access), refresh tokens stored as hash (SHA-256 or bcrypt):

```go
claims := jwt.MapClaims{
    "sub": userID,
    "exp": time.Now().Add(15 * time.Minute).Unix(), // short-lived
    "iat": time.Now().Unix(),
}
```

## A03 · Injection

**SQL injection:** use `sqlc`-generated parameterized queries — never string formatting:

```go
// ✅ sqlc-generated, parameterized
user, err := q.GetUserByEmail(ctx, email) // email is a bind parameter

// ❌ Never
row := db.QueryRow(fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email))
```

**Command injection:** never pass user input to `exec.Command`, `os.system`, or shell-executed strings.

## A04 · Insecure Design

Validate all HTTP input at the boundary before it enters domain logic:

```go
type RegisterRequest struct {
    Email string `json:"email"`
    Name  string `json:"name"`
}

func (r RegisterRequest) Validate() error {
    if r.Email == "" { return errors.New("email is required") }
    if !strings.Contains(r.Email, "@") { return errors.New("invalid email format") }
    if r.Name == "" { return errors.New("name is required") }
    if len(r.Name) > 100 { return errors.New("name too long") }
    return nil
}

func (h *Handler) register(w http.ResponseWriter, r *http.Request) {
    var req RegisterRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        renderError(w, http.StatusBadRequest, "invalid_request", "could not parse body")
        return
    }
    if err := req.Validate(); err != nil {
        renderError(w, http.StatusUnprocessableEntity, "validation_error", err.Error())
        return
    }
    // safe to pass to domain
}
```

Never trust user-controlled values for file paths, redirect URLs, or resource IDs without validation.

## A05 · Security Misconfiguration

Security headers middleware:

```go
func SecurityHeaders(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("X-Frame-Options", "DENY")
        w.Header().Set("X-XSS-Protection", "1; mode=block")
        w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
        w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
        next.ServeHTTP(w, r)
    })
}
```

CORS — restrict to known origins:

```go
corsHandler := cors.New(cors.Options{
    AllowedOrigins:   cfg.AllowedOrigins, // from config, not wildcard
    AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
    AllowedHeaders:   []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
})
```

Rate limiting on auth endpoints:

```go
r.With(rateLimiter(10, time.Minute)).Post("/auth/login", authHandler.Login)
r.With(rateLimiter(5, time.Minute)).Post("/auth/forgot-password", authHandler.ForgotPassword)
```

## A06 · Vulnerable and Outdated Components

```bash
go list -m -json all | nancy sleuth     # check for known vulnerabilities
govulncheck ./...                        # Go official vulnerability scanner
```

Run `govulncheck` in CI before every release.

## A07 · Identification and Authentication Failures

JWT validation in middleware — verify signature, expiry, and issuer:

```go
func AuthMiddleware(secret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            authHeader := r.Header.Get("Authorization")
            if !strings.HasPrefix(authHeader, "Bearer ") {
                renderError(w, http.StatusUnauthorized, "unauthorized", "missing token")
                return
            }
            token := authHeader[7:]
            claims, err := validateJWT(token, secret)
            if err != nil {
                renderError(w, http.StatusUnauthorized, "unauthorized", "invalid token")
                return
            }
            ctx := context.WithValue(r.Context(), userIDKey, claims.Subject)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

## A08 · Software and Data Integrity Failures

Always validate responses from external services before using them:

```go
// ✅ Validate external API response shape before using
var externalResp ExternalAPIResponse
if err := json.NewDecoder(resp.Body).Decode(&externalResp); err != nil {
    return nil, fmt.Errorf("unexpected external API response: %w", err)
}
if externalResp.ID == "" {
    return nil, errors.New("external API returned invalid response: missing id")
}
```

## A09 · Security Logging and Monitoring Failures

Log with `slog` at the HTTP boundary. Never log tokens, passwords, or full request bodies:

```go
// ✅
slog.InfoContext(ctx, "user registered", "user_id", user.ID, "email_domain", emailDomain)

// ❌
slog.InfoContext(ctx, "request", "body", r.Body)     // may contain passwords
slog.InfoContext(ctx, "token", "jwt", token)          // credentials in logs
```

## A10 · Server-Side Request Forgery (SSRF)

Validate URLs derived from user input before making outbound requests:

```go
// ✅ Allowlist approach
var allowedHosts = map[string]bool{
    "api.trusted.com":     true,
    "webhooks.trusted.com": true,
}

func validateWebhookURL(rawURL string) error {
    u, err := url.Parse(rawURL)
    if err != nil { return errors.New("invalid URL") }
    if u.Scheme != "https" { return errors.New("only HTTPS allowed") }
    if !allowedHosts[u.Hostname()] { return errors.New("host not allowed") }
    return nil
}
```

## Verification Checklist

- [ ] Auth middleware applied at router group level — not per-handler
- [ ] Every mutation endpoint verifies resource ownership
- [ ] Passwords hashed with bcrypt (cost ≥ 12)
- [ ] JWT has short expiry (≤ 15 min for access tokens)
- [ ] Refresh tokens stored as hash, never raw
- [ ] All HTTP input validated at the boundary with `Validate()`
- [ ] sqlc parameterized queries — no `fmt.Sprintf` in SQL
- [ ] Security headers middleware in the Chi router
- [ ] CORS restricted to known origins
- [ ] Rate limiting on auth endpoints
- [ ] `govulncheck ./...` clean in CI
- [ ] No tokens or passwords in logs
