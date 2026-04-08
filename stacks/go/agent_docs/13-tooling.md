# 13 · Tooling

Good tooling automates the boring and catches problems before they reach production. These tools are not optional — they are part of the development workflow and enforced in CI.

---

## Standard Commands via Taskfile

All standard development operations are defined in a `Taskfile.yml` at the repo root. Every developer — and CI — uses the same commands. No "it works on my machine" due to different flags or scripts.

```yaml
# Taskfile.yml
version: "3"

tasks:
  # --- Development ---
  dev:
    desc: Start the API with hot reload
    cmd: air -c .air.toml

  # --- Build ---
  build:
    desc: Build all binaries
    cmds:
      - go build -o ./bin/api ./cmd/api
      - go build -o ./bin/worker ./cmd/worker

  # --- Testing ---
  test:
    desc: Run unit tests
    cmd: go test -race -count=1 ./...

  test:integration:
    desc: Run integration tests (requires Docker)
    cmd: go test -race -count=1 -tags=integration ./...

  test:cover:
    desc: Run tests with coverage report
    cmds:
      - go test -race -coverprofile=coverage.out ./...
      - go tool cover -html=coverage.out -o coverage.html

  # --- Code Quality ---
  lint:
    desc: Run linter
    cmd: golangci-lint run ./...

  lint:fix:
    desc: Run linter and auto-fix where possible
    cmd: golangci-lint run --fix ./...

  fmt:
    desc: Format all Go files
    cmd: goimports -w .

  vet:
    desc: Run go vet
    cmd: go vet ./...

  # --- Code Generation ---
  generate:
    desc: Run all code generators (sqlc, mockery)
    cmds:
      - go generate ./...

  generate:sqlc:
    desc: Generate type-safe DB code from SQL
    cmd: sqlc generate

  generate:mocks:
    desc: Generate mocks from interfaces
    cmd: mockery --config .mockery.yml

  # --- Database ---
  db:migrate:
    desc: Run all pending migrations
    cmd: goose -dir migrations postgres "{{.DATABASE_URL}}" up

  db:rollback:
    desc: Roll back the last migration
    cmd: goose -dir migrations postgres "{{.DATABASE_URL}}" down

  db:status:
    desc: Show migration status
    cmd: goose -dir migrations postgres "{{.DATABASE_URL}}" status

  db:create:
    desc: Create a new migration file
    cmd: goose -dir migrations create {{.name}} sql

  # --- Security ---
  vuln:
    desc: Check for known vulnerabilities
    cmd: govulncheck ./...

  # --- CI (runs everything) ---
  ci:
    desc: Run the full CI suite locally
    cmds:
      - task: fmt
      - task: vet
      - task: lint
      - task: test
      - task: vuln
```

---

## Linting: `golangci-lint`

[golangci-lint](https://golangci-lint.run/) runs many linters in parallel. The config lives at `configs/golangci.yml`.

```yaml
# configs/golangci.yml
run:
  timeout: 5m
  go: "1.22"

linters:
  enable:
    - errcheck        # Enforce error checking — no unchecked errors
    - gosimple        # Simplify code where possible
    - govet           # go vet checks
    - ineffassign     # Detect ineffectual assignments
    - staticcheck     # Advanced static analysis
    - unused          # Find unused code
    - goimports       # Enforce import formatting
    - gofmt           # Enforce formatting
    - revive          # Go lint rules (successor to golint)
    - noctx           # No HTTP requests without context
    - wrapcheck       # Errors from external packages must be wrapped
    - exhaustive      # Exhaustive switch statements on enums
    - forbidigo       # Forbid specific patterns (fmt.Print in production)
    - godot           # Comments end with a period
    - misspell        # Catch common spelling mistakes
    - prealloc        # Preallocate slices where possible
    - unconvert       # Remove unnecessary type conversions

linters-settings:
  forbidigo:
    forbid:
      - pattern: "^fmt\\.Print(f|ln)?$"
        msg: "Use slog for logging instead of fmt.Print"
      - pattern: "^log\\.(Print|Fatal|Panic)(f|ln)?$"
        msg: "Use slog for logging"

  wrapcheck:
    ignorePackageGlobs:
      - "myapp/internal/*"  # Don't require wrapping our own errors

  revive:
    rules:
      - name: exported
      - name: error-naming
      - name: var-naming
```

Run linting in CI and block merges if it fails. Linting is non-negotiable.

---

## Formatting: `goimports`

`goimports` is a superset of `gofmt` — it formats code and also automatically manages import blocks. Use it instead of `gofmt`.

```bash
# Format and fix imports in all files
goimports -w .
```

Configure your editor to run `goimports` on save. The golangci-lint config enforces it in CI.

Import groups should follow this order (enforced by `goimports`):
1. Standard library
2. Third-party packages
3. Internal packages

```go
import (
    "context"
    "fmt"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/jackc/pgx/v5"

    "myapp/internal/users/domain"
    "myapp/internal/users/ports"
)
```

---

## Hot Reload: `air`

[air](https://github.com/cosmtrek/air) watches for file changes and recompiles + restarts the server automatically during development.

```toml
# .air.toml
root = "."
tmp_dir = "tmp"

[build]
  cmd = "go build -o ./tmp/main ./cmd/api"
  bin = "./tmp/main"
  include_ext = ["go"]
  exclude_dir = ["tmp", "vendor", "docs"]
  delay = 500

[log]
  time = true
```

```bash
# Start development server with hot reload
task dev
```

---

## Code Generation: `go generate`

Code generation is managed via `//go:generate` comments in source files. Running `task generate` (which calls `go generate ./...`) regenerates everything.

**sqlc — DB code from SQL:**
```go
// internal/users/adapters/postgres/generate.go
package postgres

//go:generate sqlc generate
```

**mockery — mocks from interfaces:**
```go
// internal/users/ports/generate.go
package ports

//go:generate mockery --name=UserRepository --output=../mocks --outpkg=mocks
//go:generate mockery --name=UserService --output=../mocks --outpkg=mocks
```

**Committing generated code:** Always commit generated files. This ensures:
- CI doesn't need to run generators (faster pipelines)
- Code review can see exactly what changed
- The build is fully reproducible without tools installed

---

## Vulnerability Scanning: `govulncheck`

[govulncheck](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) checks for known vulnerabilities in your dependencies, only reporting ones your code actually calls.

```bash
task vuln
```

Run this in CI and periodically locally. When a vulnerability is found, update the dependency or document why it's acceptable.

---

## CI Pipeline

Every PR should run the same checks as `task ci`. A minimal GitHub Actions setup:

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
          cache: true

      - name: Install tools
        run: |
          go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
          go install golang.org/x/vuln/cmd/govulncheck@latest

      - name: Format check
        run: goimports -l . | (! grep .)

      - name: Vet
        run: go vet ./...

      - name: Lint
        run: golangci-lint run ./...

      - name: Test
        run: go test -race -count=1 ./...

      - name: Vulnerability check
        run: govulncheck ./...
```

---

## Tool Versions

Pin tool versions to avoid "works on my machine" inconsistencies. Use a `tools.go` file to track Go-based tools:

```go
//go:build tools

package tools

import (
    _ "github.com/golangci/golangci-lint/cmd/golangci-lint"
    _ "github.com/vektra/mockery/v2"
    _ "github.com/sqlc-dev/sqlc/cmd/sqlc"
    _ "github.com/pressly/goose/v3/cmd/goose"
    _ "golang.org/x/tools/cmd/goimports"
    _ "golang.org/x/vuln/cmd/govulncheck"
)
```

```bash
# Install all tools at pinned versions from go.mod
go install tool
```

---

## Anti-Patterns

### ❌ Different lint configs per developer
Linting config lives in the repo and is the same for everyone. No `.golangci.yml` in home directories that override it.

### ❌ Generated code not committed
```bash
# In CI:
# "go generate ./..." must be run first, then tests run
# — adds minutes to the pipeline and makes it flaky
```
Commit generated files. Regenerate when sources change.

### ❌ Skipping the race detector in tests
```bash
go test ./...           # ❌ Race conditions go undetected
go test -race ./...     # ✅ Always
```

### ❌ No standard `task` targets
Every team member runs slightly different commands, resulting in "but it passes on my machine." Standardize through Taskfile.

### ❌ Suppressing linter warnings with blanket ignores
```go
//nolint:all  // ❌ Disables all linters for this file
```
If a lint rule needs to be suppressed, suppress the specific rule with a comment explaining why: `//nolint:wrapcheck // error from internal package, no wrapping needed`.

---

[← HTTP Layer](./12-http-layer.md) | [Index](./README.md)
