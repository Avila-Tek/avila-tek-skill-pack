---
description: Input validation in Express using Zod — the validate() middleware factory, body/params/query validation, and error extraction.
globs: ["src/modules/**/*.ts", "src/middleware/validate.middleware.ts", "src/shared/schemas/**/*.ts"]
alwaysApply: false
---

# Validation

## Core Rules

- **Validate at the boundary** — `req.body`, `req.params`, `req.query` are untrusted until parsed through a Zod schema
- **Zod is the single validation library** — no `class-validator`, no `joi`
- **Schema = source of truth** — infer TypeScript types with `z.infer<>`, never write duplicate interfaces
- **Validation in the router** — apply the `validate(schema)` middleware before the controller; the controller receives already-validated data

---

## Schema Definition

```typescript
// modules/users/dto/create-user.dto.ts
import { z } from 'zod'

export const createUserSchema = z.object({
  email: z.string().email({ message: 'Invalid email address' }),
  name: z.string().min(2).max(100),
  role: z.enum(['admin', 'member']).default('member'),
  age: z.number().int().min(18).optional(),
})

export type CreateUserDto = z.infer<typeof createUserSchema>

// Params
export const userParamsSchema = z.object({
  id: z.string().uuid({ message: 'id must be a valid UUID' }),
})

// Query
export const userQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().optional(),
})
```

---

## The `validate()` Middleware Factory

```typescript
// middleware/validate.middleware.ts
import { Request, Response, NextFunction } from 'express'
import { ZodSchema, ZodError } from 'zod'
import { ValidationError } from '../shared/errors/validation-error'
import { extractZodIssues } from '../shared/errors/extract-zod-issues'

type RequestTarget = 'body' | 'params' | 'query'

export function validate(schema: ZodSchema, target: RequestTarget = 'body') {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req[target])

    if (!result.success) {
      next(new ValidationError(extractZodIssues(result.error)))
      return
    }

    // Replace the raw value with the parsed (and coerced) value
    req[target] = result.data
    next()
  }
}
```

Applying to routes:

```typescript
// users.router.ts
router.post('/', validate(createUserSchema), asyncHandler(controller.create))
router.get('/', validate(userQuerySchema, 'query'), asyncHandler(controller.findAll))
router.patch('/:id', validate(userParamsSchema, 'params'), validate(updateUserSchema), asyncHandler(controller.update))
```

---

## Zod Issue Extraction

```typescript
// shared/errors/extract-zod-issues.ts
import { ZodError } from 'zod'

export interface FieldError {
  field: string
  message: string
}

export function extractZodIssues(error: ZodError): FieldError[] {
  return error.issues.map((issue) => ({
    field: issue.path.join('.'),
    message: issue.message,
  }))
}
```

---

## Validating Params and Query

```typescript
// Validate params before calling controller
router.get('/:id',
  validate(userParamsSchema, 'params'),
  asyncHandler(controller.findById),
)

// Validate query string for list endpoints
router.get('/',
  validate(userQuerySchema, 'query'),
  asyncHandler(controller.findAll),
)

// Validate both params and body for update
router.patch('/:id',
  validate(userParamsSchema, 'params'),
  validate(updateUserSchema, 'body'),
  asyncHandler(controller.update),
)
```

---

## Query Parameter Coercion

Query string values are always strings by default. Use `z.coerce` to convert:

```typescript
const querySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),    // "2" → 2
  active: z.coerce.boolean().optional(),              // "true" → true
  limit: z.coerce.number().int().max(100).default(20),
})
```

---

## Nested and Conditional Schemas

```typescript
// Nested object
const addressSchema = z.object({
  street: z.string(),
  city: z.string(),
  country: z.string().length(2),
})

const createProfileSchema = z.object({
  bio: z.string().max(500).optional(),
  address: addressSchema.optional(),
})

// Conditional validation
const paymentSchema = z.discriminatedUnion('method', [
  z.object({ method: z.literal('card'), cardNumber: z.string().length(16) }),
  z.object({ method: z.literal('bank'), iban: z.string() }),
])
```

---

## Anti-Patterns

```typescript
// ❌ Trusting req.body without validation
router.post('/users', asyncHandler(async (req, res) => {
  const { email, name } = req.body // unsafe — could be anything
  await userService.create({ email, name })
}))

// ✅ validate() middleware runs before the handler
router.post('/users', validate(createUserSchema), asyncHandler(async (req, res) => {
  const dto = req.body as CreateUserDto // already parsed and safe
  await userService.create(dto)
}))
```

```typescript
// ❌ Validating inside a controller
async create(req: Request, res: Response) {
  const result = createUserSchema.safeParse(req.body) // wrong layer
  if (!result.success) return res.status(400).json(...)
  ...
}

// ✅ Validation is the router's responsibility
router.post('/', validate(createUserSchema), asyncHandler(controller.create))
// By the time controller.create runs, req.body is already valid
```

```typescript
// ❌ Writing duplicate interfaces
interface CreateUserBody {   // duplicates the Zod schema
  email: string
  name: string
}

// ✅ Infer from schema
export type CreateUserDto = z.infer<typeof createUserSchema>
```

```typescript
// ❌ Forgetting to call next() after validation fails — request hangs
export function validate(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body)
    if (!result.success) {
      res.status(400).json({ error: 'invalid' }) // never calls next — error middleware skipped
    }
    next()
  }
}

// ✅ Call next(error) to forward to the error middleware
export function validate(schema: ZodSchema) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body)
    if (!result.success) {
      next(new ValidationError(extractZodIssues(result.error)))
      return
    }
    req.body = result.data
    next()
  }
}
```
