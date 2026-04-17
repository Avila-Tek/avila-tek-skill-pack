---
description: AppError hierarchy, setErrorHandler, error response envelope, and error handling patterns for Fastify.
globs: ["src/**/*.ts"]
alwaysApply: false
---

# Error Handling

## Core Principle

Services and repositories throw typed `AppError` subclasses. The HTTP layer — specifically `setErrorHandler` — is the **only** place that serializes error responses. Route handlers and controllers never catch domain errors; they simply let them propagate.

---

## `AppError` Base Class

```typescript
// shared/errors/app-error.ts
export class AppError extends Error {
  constructor(
    message: string,
    public readonly statusCode: number,
    public readonly code: string,
    public readonly details?: unknown,
  ) {
    super(message)
    this.name = this.constructor.name
    Error.captureStackTrace(this, this.constructor)
  }
}
```

---

## Typed Subclasses

```typescript
// shared/errors/not-found-error.ts
export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404, 'NOT_FOUND')
  }
}

// shared/errors/validation-error.ts
import type { FieldError } from './extract-zod-issues'
export class ValidationError extends AppError {
  constructor(details?: FieldError[]) {
    super('Validation failed', 400, 'VALIDATION_ERROR', details)
  }
}

// shared/errors/conflict-error.ts
export class ConflictError extends AppError {
  constructor(message = 'Resource already exists') {
    super(message, 409, 'CONFLICT')
  }
}

// shared/errors/unauthorized-error.ts
export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required') {
    super(message, 401, 'UNAUTHORIZED')
  }
}

// shared/errors/forbidden-error.ts
export class ForbiddenError extends AppError {
  constructor(message = 'Insufficient permissions') {
    super(message, 403, 'FORBIDDEN')
  }
}
```

---

## Error Response Envelope

All error responses follow this shape:

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "User not found",
    "details": null
  }
}
```

For validation errors, `details` contains field-level errors:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed",
    "details": [
      { "field": "email", "message": "Invalid email address" },
      { "field": "name", "message": "String must contain at least 2 character(s)" }
    ]
  }
}
```

---

## `setErrorHandler`

Register in `app.ts` after all plugins and routes:

```typescript
// shared/errors/error-handler.ts
import { FastifyError, FastifyInstance, FastifyReply, FastifyRequest } from 'fastify'
import { AppError } from './app-error'

export function errorHandler(
  error: FastifyError | AppError | Error,
  request: FastifyRequest,
  reply: FastifyReply,
) {
  // Known domain error
  if (error instanceof AppError) {
    return reply.code(error.statusCode).send({
      error: {
        code: error.code,
        message: error.message,
        details: error.details ?? null,
      },
    })
  }

  // Fastify validation error (when using schema: on routes)
  if ('statusCode' in error && error.statusCode === 400) {
    return reply.code(400).send({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: error.message,
      },
    })
  }

  // Unknown / unexpected error — log and return 500
  request.log.error({ err: error }, 'Unexpected error')
  return reply.code(500).send({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      details: null,
    },
  })
}
```

```typescript
// app.ts
import { errorHandler } from './shared/errors/error-handler'

fastify.setErrorHandler(errorHandler)
```

---

## Throwing Errors in Services

```typescript
// users.service.ts
class UserService {
  async findById(id: string): Promise<User> {
    const user = await this.repo.findById(id)
    if (!user) throw new NotFoundError(`User ${id} not found`)
    return user
  }

  async create(dto: CreateUserDto): Promise<User> {
    const existing = await this.repo.findByEmail(dto.email)
    if (existing) throw new ConflictError('Email already registered')
    return this.repo.create(dto)
  }
}
```

The route handler requires **no try/catch**:

```typescript
// In a route handler — errors propagate automatically to setErrorHandler
fastify.get('/:id', { schema: { params: userParamsSchema } }, async (request, reply) => {
  const user = await userService.findById(request.params.id)
  reply.send(toUserResponse(user))
})
```

---

## Never Leak Internal Details

```typescript
// ❌ Exposing stack trace or ORM error
fastify.setErrorHandler((error, request, reply) => {
  reply.code(500).send({ error: error.message, stack: error.stack }) // dangerous
})

// ❌ Exposing DB error messages
throw new Error(drizzleError.message) // may contain table names, column names, query fragments

// ✅ Wrap with AppError
if (drizzleError.code === '23505') throw new ConflictError('Email already registered')
throw new InternalError() // generic 500 — log the original, don't expose it
```

---

## Anti-Patterns

```typescript
// ❌ Error serialized inside a route handler
fastify.get('/users/:id', async (request, reply) => {
  try {
    const user = await userService.findById(request.params.id)
    reply.send(user)
  } catch (err) {
    reply.code(404).send({ error: 'not found' }) // bypasses setErrorHandler, inconsistent format
  }
})

// ✅ Let errors propagate — setErrorHandler catches everything
fastify.get('/users/:id', { schema: { params: userParamsSchema } }, async (request, reply) => {
  const user = await userService.findById(request.params.id)
  reply.send(toUserResponse(user))
})
```

```typescript
// ❌ Throwing bare Error — no HTTP status, no code, produces 500
throw new Error('User not found')

// ✅ Throw typed AppError subclass
throw new NotFoundError('User not found')
```
