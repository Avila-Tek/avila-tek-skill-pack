---
description: Testing strategy for Fastify — Vitest, buildApp factory, app.inject(), unit vs integration tests, mock patterns.
globs: ["src/**/*.spec.ts", "src/**/*.test.ts"]
alwaysApply: false
---

# Testing

## Test Pyramid

```
           /\
          /E2E\          (minimal — full stack, external services)
         /──────\
        /Integr. \       (route-level — app.inject(), real service layer)
       /────────────\
      /  Unit Tests  \   (service + repository in isolation — most tests)
     /────────────────\
```

- **Unit tests**: service and repository logic, no HTTP, no real DB (use in-memory or mock)
- **Integration tests**: full route stack via `app.inject()`, real service + repository (test DB)
- **E2E tests**: sparingly — reserve for critical user flows

---

## Setup

```bash
pnpm add -D vitest @vitest/coverage-v8
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

Never share a Fastify instance between tests. Export a factory function from `app.ts`:

```typescript
// app.ts
export async function buildApp(overrides?: Partial<AppOptions>) {
  const fastify = Fastify({ logger: false }) // disable logger in tests
    .withTypeProvider<ZodTypeProvider>()

  fastify.setValidatorCompiler(validatorCompiler)
  fastify.setSerializerCompiler(serializerCompiler)

  await fastify.register(configPlugin)
  await fastify.register(databasePlugin)
  await fastify.register(authPlugin)
  await fastify.register(usersPlugin, { prefix: '/api/v1' })
  fastify.setErrorHandler(errorHandler)

  return fastify
}
```

---

## Integration Tests with `app.inject()`

`app.inject()` simulates an HTTP request without binding to a port — fast and clean.

```typescript
// modules/users/users.integration.spec.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { buildApp } from '../../app'
import type { FastifyInstance } from 'fastify'

describe('POST /api/v1/users', () => {
  let app: FastifyInstance

  beforeAll(async () => {
    app = await buildApp()
    await app.ready()
  })

  afterAll(async () => {
    await app.close()
  })

  it('creates a user and returns 201', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/users',
      payload: { email: 'test@example.com', name: 'Alice', role: 'member' },
      headers: { authorization: `Bearer ${generateTestToken()}` },
    })

    expect(response.statusCode).toBe(201)
    const body = response.json()
    expect(body).toMatchObject({ email: 'test@example.com', name: 'Alice' })
    expect(body.id).toBeDefined()
  })

  it('returns 400 for invalid payload', async () => {
    const response = await app.inject({
      method: 'POST',
      url: '/api/v1/users',
      payload: { email: 'not-an-email' },
      headers: { authorization: `Bearer ${generateTestToken()}` },
    })

    expect(response.statusCode).toBe(400)
    expect(response.json().error.code).toBe('VALIDATION_ERROR')
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

Use a real test DB (SQLite in-memory or a test Postgres instance with a separate database).

```typescript
// modules/users/users.repository.spec.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { drizzle } from 'drizzle-orm/better-sqlite3'
import Database from 'better-sqlite3'
import { UsersRepository } from './users.repository'

describe('UsersRepository', () => {
  let db: ReturnType<typeof drizzle>
  let repo: UsersRepository

  beforeAll(() => {
    const sqlite = new Database(':memory:')
    db = drizzle(sqlite)
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
// ❌ Sharing app instance between test files — state bleeds between tests
const app = await buildApp() // module-level, shared
describe('test A', ...) // modifies state
describe('test B', ...) // sees state from A

// ✅ Create fresh app per describe block
beforeAll(async () => { app = await buildApp() })
afterAll(async () => { await app.close() })
```

```typescript
// ❌ Testing business logic through HTTP (use unit test instead)
it('throws when user not found', async () => {
  const response = await app.inject({ method: 'GET', url: '/api/v1/users/missing-id' })
  expect(response.statusCode).toBe(404)
  // This tests the full stack for a unit-level concern — slow and fragile
})

// ✅ Test the service directly
it('throws NotFoundError', async () => {
  vi.mocked(repo.findById).mockResolvedValue(null)
  await expect(service.findById('missing')).rejects.toThrow(NotFoundError)
})
```
