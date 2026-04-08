# 02 · Package Design

In Go, a package is both a compilation unit and a namespace. Poor package design is the most common reason large Go codebases become hard to work in — it causes circular imports, bloated dependencies, and loss of encapsulation. Getting this right early pays dividends forever.

---

## Naming

Package names are part of the API. When you write `user.Service`, the package name is doing meaningful work.

**Rules:**
- Lowercase, single word. No underscores, no camelCase: `users`, `auth`, `billing`.
- A package name should describe **what it provides**, not what it contains. `parser` over `parsing`, `errors` over `errorhandling`.
- Avoid generic names: `util`, `common`, `misc`, `base`, `helper`, `shared` are all warning signs.
- Avoid stuttering: if the package is named `user`, the type inside it should be `Service`, not `UserService`. The caller writes `user.Service` — the context is already there.

```go
// ✅ Good — the package name provides context
package user

type Service struct { ... }
type Repository interface { ... }

// Caller reads: user.Service, user.Repository — clear and concise
```

```go
// ❌ Bad — stutter
package user

type UserService struct { ... }   // Caller reads: user.UserService
type UserRepository interface { } // Caller reads: user.UserRepository
```

---

## Cohesion: What Belongs in a Package

A package should represent a single, coherent concept. The test: **can you describe what the package does in one sentence without using the word "and"?**

If a package grows to contain unrelated things — structs for users AND orders AND billing AND config parsing — it's time to split it.

```go
// ✅ Good — single responsibility
package pagination

type Params struct {
    Page  int
    Limit int
}

func (p Params) Offset() int {
    return (p.Page - 1) * p.Limit
}
```

```go
// ❌ Bad — mixed concerns
package utils

func Paginate(page, limit int) int { ... }
func HashPassword(pw string) string { ... }
func FormatDate(t time.Time) string { ... }
func SendEmail(to, body string) error { ... }
```

---

## The `internal/` Boundary

The `internal/` directory is Go's built-in encapsulation mechanism. Code in `internal/` cannot be imported by packages outside the module root. Use it deliberately:

- All domain-specific code lives under `internal/`.
- Packages in `internal/` can be freely refactored without worrying about external consumers.
- If code genuinely needs to be consumed by other projects, it belongs in `pkg/`.

```
internal/users/      ← only importable within this module
pkg/apierrors/       ← designed to be imported externally
```

---

## Package Boundaries Follow Domain Boundaries

Structure packages around **business domains**, not technical layers. Each domain package owns its domain's types, logic, and data access — the layering happens *inside* the domain package (see [Architecture](./03-architecture.md)).

```
// ✅ Good — domain-oriented
internal/
├── users/
├── orders/
└── billing/

// ❌ Bad — layer-oriented (couples all domains together)
internal/
├── handlers/
├── services/
└── repositories/
```

---

## When to Split a Package

Split a package when:
1. It has grown beyond ~500–800 lines and contains multiple distinct concepts.
2. Two different consumers need different subsets of it (and would rather not import the whole thing).
3. It has a dependency that only some of its code needs, and you want to avoid that dependency for other consumers.

Don't split a package just because it's "big." Cohesion matters more than size.

---

## Circular Imports

Go does not allow circular imports. If you find yourself needing a circular import, it's a signal that your package boundaries are wrong.

**Common causes and fixes:**

| Cause | Fix |
|-------|-----|
| Package A and B both need a shared type | Extract the type to a third package C, imported by both |
| A service imports its own repository interface | The interface should be defined where it's consumed (see [Interface Design](./04-interface-design.md)) |
| Two domains are too tightly coupled | Reconsider whether they should be one domain or communicate via events |

---

## Anti-Patterns

### ❌ The `utils` Package
```go
package utils

// A graveyard of functions that didn't have a home.
// No one knows what's in here without reading it entirely.
// Everyone adds to it. No one refactors it.
```
**Fix:** Ask what each function *actually does*. Group by concept into a properly named package: `timeutil`, `pagination`, `httputil`, `validation`.

### ❌ The `models` Package
```go
package models

type User struct { ... }
type Order struct { ... }
type Product struct { ... }
type Invoice struct { ... }
```
This breaks encapsulation completely. Every domain's types are globally visible to every other domain. Business logic leaks everywhere because the types are imported everywhere.

**Fix:** Each domain owns its types. `users.User`, `orders.Order`, `products.Product` — living in their respective packages.

### ❌ The `types` or `dto` Package
Similar problem to `models`. Don't create a central package for request/response types that aggregates across domains.

**Fix:** Request/response DTOs belong in the adapter package that uses them: `users/adapters/http/dto.go`.

### ❌ Naming a package the same as a stdlib package
```go
package errors  // Now you shadow the standard library
package context
package http
```
Always pick names that don't shadow the standard library.

---

[← Project Layout](./01-project-layout.md) | [Index](./README.md) | [Next: Architecture →](./03-architecture.md)
