---
description: Input validation in Fastify using Zod and fastify-type-provider-zod — schema-first routes, param/query validation, and error extraction.
globs: ["src/modules/**/*.ts", "src/shared/schemas/**/*.ts"]
alwaysApply: false
---

# Validation

## Core Rules

- **Validate at the boundary** — `request.body`, `request.params`, `request.query` are untrusted until parsed through a Zod schema
- **Zod is the single validation library** — no `class-validator`, no `joi`, no AJV schemas written by hand
- **Schema = source of truth** — infer TypeScript types with `z.infer<>`, never write duplicate interfaces
- **Validation happens before the handler** — use the `schema:` option on every route so Fastify validates and coerces before your code runs

---

## Setup: `fastify-type-provider-zod`

Install once in `app.ts`:

```typescript
import Fastify from 'fastify'
import { serializerCompiler, validatorCompiler, ZodTypeProvider } from 'fastify-type-provider-zod'

export async function buildApp() {
  const fastify = Fastify({ logger: true }).withTypeProvider<ZodTypeProvider>()

  fastify.setValidatorCompiler(validatorCompiler)
  fastify.setSerializerCompiler(serializerCompiler)

  // ... register plugins and routes
  return fastify
}
```

---

## Schema Definition

```typescript
// dto/create-user.dto.ts
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

## Route Schema Options

Declaring schemas on a route gives you three things:
1. Automatic validation before the handler runs (400 returned on failure)
2. Type-safe `request.body` / `request.params` / `request.query`
3. Faster JSON serialization for the response

```typescript
// users.routes.ts
import { FastifyInstance } from 'fastify'
import { ZodTypeProvider } from 'fastify-type-provider-zod'
import { createUserSchema, userParamsSchema, userQuerySchema } from './dto/create-user.dto'
import { userResponseSchema } from './dto/user.response'

export async function userRoutes(fastify: FastifyInstance) {
  const f = fastify.withTypeProvider<ZodTypeProvider>()

  f.post('/', {
    schema: {
      body: createUserSchema,
      response: { 201: userResponseSchema },
    },
  }, async (request, reply) => {
    // request.body is fully typed as CreateUserDto — no cast needed
    const user = await controller.create(request, reply)
  })

  f.get('/', {
    schema: {
      querystring: userQuerySchema,
      response: { 200: paginatedUserResponseSchema },
    },
  }, controller.findAll)

  f.get('/:id', {
    schema: {
      params: userParamsSchema,
      response: { 200: userResponseSchema },
    },
  }, controller.findById)
}
```

---

## Manual Validation (Fallback)

When you need validation inside a service or in a `preHandler` hook, use `.safeParse()`:

```typescript
const result = createUserSchema.safeParse(data)

if (!result.success) {
  throw new ValidationError(extractZodIssues(result.error))
}

const dto = result.data // type-safe
```

Extract Zod issues into a consistent format:

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

## Query Parameter Coercion

Query string values are always strings by default. Use `z.coerce` to convert to numbers/booleans:

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
// ❌ Trusting request.body without a schema
fastify.post('/users', async (request, reply) => {
  const { email, name } = request.body as any // unsafe cast
  await userService.create({ email, name })
})

// ✅ Schema on route — Fastify validates before handler runs
fastify.post('/users', { schema: { body: createUserSchema } }, async (request, reply) => {
  // request.body is CreateUserDto
  await userService.create(request.body)
})
```

```typescript
// ❌ Validating inside the service
class UserService {
  async create(data: unknown) {
    const result = createUserSchema.safeParse(data) // wrong layer
    ...
  }
}

// ✅ Validate at the route boundary; service receives typed DTO
class UserService {
  async create(dto: CreateUserDto) { // already validated
    ...
  }
}
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
