---
description: Testing strategy for Express — Vitest, buildApp factory, supertest, unit vs integration tests, mock patterns.
globs: ["src/**/*.spec.ts", "src/**/*.test.ts"]
alwaysApply: false
---

# Testing

## Test Pyramid

```
           /\
          /E2E\          (minimal — full stack, external services)
         /──────\
        /Integr. \       (route-level — supertest, real service layer)
       /────────────\
      /  Unit Tests  \   (service + repository in isolation — most tests)
     /────────────────\
```

- **Unit tests**: service and repository logic, no HTTP, no real DB (use in-memory or mock)
- **Integration tests**: full route stack via `supertest`, real service + repository (test DB)
- **E2E tests**: sparingly — reserve for critical user flows

---

## Setup

```bash
pnpm add -D vitest @vitest/coverage-v8 supertest @types/supertest
```

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      thresholds: { lines: 80, functions: 80, branches: 80 },
      exclude: ['src/server.ts', 'src/config/**'],
    },
  },
})
```

---

## `buildApp()` Factory

Keep `app.ts` and `server.ts` separate. `app.ts` exports a factory that creates the Express app without binding to a port — this is what tests import.

```typescript
// app.ts
import express from 'express'
import { createV1Router } from './routes/v1'
import { errorHandler } from './middleware/error.middleware'

export function buildApp() {
  const app = express()
  app.use(express.json())
  app.use('/api/v1', createV1Router())
  app.use(errorHandler)
  return app
}

// server.ts — NOT imported in tests
import { buildApp } from './app'
const app = buildApp()
app.listen(3000)
```

---

## Integration Tests with `supertest`

`supertest` makes HTTP requests against the app without binding to a port.

```typescript
// modules/users/users.integration.spec.ts
import { describe, it, expect } from 'vitest'
import request from 'supertest'
import { buildApp } from '../../app'

const app = buildApp()

describe('POST /api/v1/users', () => {
  it('creates a user and returns 201', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${generateTestToken()}`)
      .send({ email: 'test@example.com', name: 'Alice', role: 'member' })

    expect(response.status).toBe(201)
    expect(response.body).toMatchObject({ email: 'test@example.com', name: 'Alice' })
    expect(response.body.id).toBeDefined()
  })

  it('returns 400 for invalid payload', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${generateTestToken()}`)
      .send({ email: 'not-an-email' })

    expect(response.status).toBe(400)
    expect(response.body.error.code).toBe('VALIDATION_ERROR')
  })

  it('returns 401 without token', async () => {
    const response = await request(app)
      .post('/api/v1/users')
      .send({ email: 'test@example.com', name: 'Alice' })

    expect(response.status).toBe(401)
  })
})
```

---

## Unit Tests — Service Layer

Test services with mock repositories. Never use a real DB in unit tests.

```typescript
// modules/users/users.service.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { UserService } from './users.service'
import { NotFoundError } from '../../shared/errors/not-found-error'
import { ConflictError } from '../../shared/errors/conflict-error'
import type { IUsersRepository } from './users.repository.interface'

function makeMockRepo(): IUsersRepository {
  return {
    findById: vi.fn(),
    findByEmail: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    remove: vi.fn(),
    findAll: vi.fn(),
  }
}

describe('UserService.findById', () => {
  let repo: IUsersRepository
  let service: UserService

  beforeEach(() => {
    repo = makeMockRepo()
    service = new UserService(repo)
  })

  it('returns the user when found', async () => {
    const mockUser = { id: '1', email: 'a@b.com', name: 'Alice', role: 'member', createdAt: new Date() }
    vi.mocked(repo.findById).mockResolvedValue(mockUser)

    const result = await service.findById('1')
    expect(result).toEqual(mockUser)
    expect(repo.findById).toHaveBeenCalledWith('1')
  })

  it('throws NotFoundError when user does not exist', async () => {
    vi.mocked(repo.findById).mockResolvedValue(null)
    await expect(service.findById('missing')).rejects.toThrow(NotFoundError)
  })
})

describe('UserService.create', () => {
  it('throws ConflictError when email already exists', async () => {
    const repo = makeMockRepo()
    const service = new UserService(repo)
    vi.mocked(repo.findByEmail).mockResolvedValue({ id: '1' } as any)

    await expect(service.create({ email: 'dup@b.com', name: 'Bob', role: 'member' }))
      .rejects.toThrow(ConflictError)
  })
})
```

---

## Unit Tests — Repository Layer

Use a real test DB (SQLite in-memory or a dedicated test Postgres database).

```typescript
// modules/users/users.repository.spec.ts
import { describe, it, expect, beforeAll } from 'vitest'
import { drizzle } from 'drizzle-orm/better-sqlite3'
import Database from 'better-sqlite3'
import { UsersRepository } from './users.repository'

describe('UsersRepository', () => {
  let repo: UsersRepository

  beforeAll(() => {
    const sqlite = new Database(':memory:')
    const db = drizzle(sqlite)
    // run migrations
    repo = new UsersRepository(db)
  })

  it('creates and retrieves a user', async () => {
    const created = await repo.create({ email: 'a@b.com', name: 'Alice', role: 'member' })
    const found = await repo.findById(created.id)
    expect(found).toEqual(created)
  })

  it('returns null for unknown id', async () => {
    const found = await repo.findById('00000000-0000-0000-0000-000000000000')
    expect(found).toBeNull()
  })
})
```

---

## Test JWT Helper

```typescript
// test/helpers/jwt.ts
import jwt from 'jsonwebtoken'

export function generateTestToken(overrides: Partial<JwtPayload> = {}) {
  return jwt.sign(
    { sub: 'test-user-id', email: 'test@example.com', role: 'member', ...overrides },
    process.env.JWT_SECRET ?? 'test-secret',
    { expiresIn: '1h' },
  )
}
```

---

## Anti-Patterns

```typescript
// ❌ Importing server.ts in tests — binds to a real port, causes EADDRINUSE
import './server' // wrong
import request from 'supertest'

// ✅ Import app.ts factory — no port binding
import { buildApp } from './app'
const app = buildApp()
```

```typescript
// ❌ Sharing app with mutable state between describe blocks
let app = buildApp() // module-level — state leaks between tests

// ✅ Recreate per describe block if needed, or use stateless factory
const app = buildApp() // OK if buildApp() returns a fresh app with no shared state
```

```typescript
// ❌ Testing business logic through HTTP (use unit test instead)
it('throws when user not found', async () => {
  const response = await request(app).get('/api/v1/users/missing')
  expect(response.status).toBe(404)
  // Slow and fragile — tests the full stack for a unit-level concern
})

// ✅ Test the service directly
it('throws NotFoundError', async () => {
  vi.mocked(repo.findById).mockResolvedValue(null)
  await expect(service.findById('missing')).rejects.toThrow(NotFoundError)
})
```
