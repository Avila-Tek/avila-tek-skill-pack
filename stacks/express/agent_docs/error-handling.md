---
description: AppError hierarchy, 4-arg error middleware, asyncHandler wrapper, and error handling patterns for Express.
globs: ["src/**/*.ts"]
alwaysApply: false
---

# Error Handling

## Core Principle

Services and repositories throw typed `AppError` subclasses. The HTTP layer — specifically the 4-argument error middleware — is the **only** place that serializes error responses. Controllers never serialize errors inline; they call `next(err)` (via `asyncHandler`) and let the middleware handle it.

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

## The 4-Argument Error Middleware

The signature must have **exactly 4 arguments** — Express uses the arity to identify error middleware. Must be registered **last** in `app.ts`.

```typescript
// middleware/error.middleware.ts
import { Request, Response, NextFunction } from 'express'
import { AppError } from '../shared/errors/app-error'

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction, // must be present even if unused
): void {
  // Known domain error
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details ?? null,
      },
    })
    return
  }

  // Unknown / unexpected error — log and return 500
  console.error(err) // replace with your logger
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: 'An unexpected error occurred',
      details: null,
    },
  })
}
```

```typescript
// app.ts — MUST be the last app.use() call
app.use('/api/v1', v1Router)
app.use(notFoundHandler)  // catches unmatched routes
app.use(errorHandler)     // catches all next(err) calls — LAST
```

---

## `asyncHandler` Wrapper

Async route handlers throw rejected promises. Without `asyncHandler`, these are unhandled rejections that bypass the error middleware and crash the process.

```typescript
// middleware/asyncHandler.ts
import { Request, Response, NextFunction, RequestHandler } from 'express'

export function asyncHandler(fn: RequestHandler): RequestHandler {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next)
  }
}
```

Apply in the router, not the controller:

```typescript
// ✅ asyncHandler wraps the controller method in the router
router.post('/', validate(createUserSchema), asyncHandler(controller.create))

// ❌ Never do try/catch in the controller just to call next(err)
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await this.service.create(req.body)
    res.status(201).json(toUserResponse(user))
  } catch (err) {
    next(err) // correct intent, but asyncHandler makes this unnecessary
  }
}
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

The controller requires **no error handling**:

```typescript
// Controller — clean, no try/catch needed
create = async (req: Request, res: Response): Promise<void> => {
  const user = await this.service.create(req.body as CreateUserDto)
  res.status(201).json(toUserResponse(user))
}
// If service throws, asyncHandler forwards to errorHandler automatically
```

---

## 404 Handler

Register before `errorHandler` to catch unmatched routes:

```typescript
// middleware/not-found.middleware.ts
import { Request, Response, NextFunction } from 'express'
import { NotFoundError } from '../shared/errors/not-found-error'

export function notFoundHandler(req: Request, res: Response, next: NextFunction): void {
  next(new NotFoundError(`Route ${req.method} ${req.path} not found`))
}
```

---

## Never Leak Internal Details

```typescript
// ❌ Exposing stack trace or DB error
res.status(500).json({ error: err.message, stack: err.stack })

// ❌ Forwarding raw DB error message
throw new Error(drizzleError.message) // may contain table names, column names

// ✅ Wrap DB errors in AppError
if (dbError.code === '23505') throw new ConflictError('Email already registered')
// Unknown DB errors → let errorHandler produce a generic 500; log original internally
```

---

## Anti-Patterns

```typescript
// ❌ Error serialized inline — bypasses errorHandler, inconsistent format
router.get('/users/:id', async (req, res) => {
  try {
    const user = await userService.findById(req.params.id)
    res.json(user)
  } catch {
    res.status(404).json({ error: 'not found' }) // should never do this
  }
})

// ✅ Let asyncHandler forward to errorHandler
router.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await userService.findById(req.params.id)
  res.json(toUserResponse(user))
}))
```

```typescript
// ❌ Error middleware with wrong arity — Express won't recognize it
app.use((err: Error, req: Request, res: Response) => { // missing next parameter!
  res.status(500).json({ error: err.message })
})

// ✅ Must have exactly 4 parameters
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  // ...
})
```

```typescript
// ❌ Throwing bare Error — no HTTP status, produces generic 500
throw new Error('User not found')

// ✅ Throw typed AppError subclass
throw new NotFoundError('User not found')
```
