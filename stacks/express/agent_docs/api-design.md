---
description: REST conventions, request DTOs, response mapping, pagination, CRUD patterns, and controller signatures for Express.
globs: ["src/modules/**/*.ts"]
alwaysApply: false
---

# API Design

## REST Conventions

### URL Naming

- Resources are **plural nouns**: `/users`, `/orders`, `/products`
- Nested resources for ownership: `/users/:userId/orders`
- Actions that don't map to CRUD use verbs: `/auth/login`, `/auth/logout`
- All lowercase, hyphen-separated: `/product-categories`

### HTTP Verbs and Status Codes

| Operation | Method | Success status | Notes |
|-----------|--------|---------------|-------|
| Create | POST | 201 | Body contains created resource |
| Read one | GET | 200 | 404 if not found |
| Read list | GET | 200 | Never 204 for lists |
| Update (partial) | PATCH | 200 | Body contains updated resource |
| Update (full) | PUT | 200 | Idempotent |
| Delete | DELETE | 204 | No body |
| Login / token | POST | 200 | |
| Validation error | — | 400 | `code: 'VALIDATION_ERROR'` |
| Unauthenticated | — | 401 | `code: 'UNAUTHORIZED'` |
| Forbidden | — | 403 | `code: 'FORBIDDEN'` |
| Not found | — | 404 | `code: 'NOT_FOUND'` |
| Conflict | — | 409 | `code: 'CONFLICT'` |
| Internal error | — | 500 | Never expose stack traces |

---

## Request DTOs

Define a Zod schema and infer the TypeScript type from it. Never write a duplicate interface.

```typescript
// modules/users/dto/create-user.dto.ts
import { z } from 'zod'

export const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(['admin', 'member']).default('member'),
})

export type CreateUserDto = z.infer<typeof createUserSchema>

// Params schema
export const getUserParamsSchema = z.object({
  id: z.string().uuid(),
})

export type GetUserParams = z.infer<typeof getUserParamsSchema>
```

Use the `validate()` middleware factory to enforce schemas at the router level:

```typescript
router.post('/', validate(createUserSchema), asyncHandler(controller.create))
router.patch('/:id', validate(updateUserSchema), asyncHandler(controller.update))
```

Inside the controller, cast the validated body to the DTO type — it is already parsed by the middleware:

```typescript
const dto = req.body as CreateUserDto
```

---

## Response Mapping

Never expose raw ORM rows or domain objects. Always map through a response function.

```typescript
// modules/users/dto/user.response.ts
export interface UserResponse {
  id: string
  email: string
  name: string
  role: string
  createdAt: string
}

export function toUserResponse(user: {
  id: string
  email: string
  name: string
  role: string
  createdAt: Date
}): UserResponse {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    createdAt: user.createdAt.toISOString(),
  }
}
```

```typescript
// ❌ Exposing raw DB row
res.status(201).json(userFromDb) // may include passwordHash, internalFields

// ✅ Always map
res.status(201).json(toUserResponse(userFromDb))
```

---

## Pagination

Standard query params: `?page=1&limit=20` (1-indexed pages).

```typescript
// shared/schemas/pagination.schema.ts
import { z } from 'zod'

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

export type PaginationQuery = z.infer<typeof paginationSchema>
```

Response shape for paginated lists:

```typescript
export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

export function toPaginatedResponse<T>(
  items: T[],
  total: number,
  page: number,
  limit: number,
): PaginatedResponse<T> {
  return {
    data: items,
    meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
  }
}
```

---

## CRUD Pattern Walkthrough

```typescript
// users.router.ts
export function createUserRouter(controller: UserController): Router {
  const router = Router()

  router.post('/', validate(createUserSchema), asyncHandler(controller.create))
  router.get('/', validate(paginationSchema, 'query'), asyncHandler(controller.findAll))
  router.get('/:id', asyncHandler(controller.findById))
  router.patch('/:id', validate(updateUserSchema), asyncHandler(controller.update))
  router.delete('/:id', asyncHandler(controller.remove))

  return router
}
```

```typescript
// users.controller.ts
export class UserController {
  constructor(private readonly service: UserService) {}

  create = async (req: Request, res: Response): Promise<void> => {
    const user = await this.service.create(req.body as CreateUserDto)
    res.status(201).json(toUserResponse(user))
  }

  findById = async (req: Request, res: Response): Promise<void> => {
    const user = await this.service.findById(req.params.id)
    res.json(toUserResponse(user))
  }

  findAll = async (req: Request, res: Response): Promise<void> => {
    const query = req.query as unknown as PaginationQuery
    const { items, total } = await this.service.findAll(query)
    res.json(toPaginatedResponse(items.map(toUserResponse), total, query.page, query.limit))
  }

  remove = async (req: Request, res: Response): Promise<void> => {
    await this.service.remove(req.params.id)
    res.status(204).send()
  }
}
```

---

## Controller Signature Rules

Every controller method must follow this pattern:

```typescript
// Correct signature for async methods
methodName = async (req: Request, res: Response): Promise<void> => {
  // ... 
}

// asyncHandler is applied in the ROUTER, not the controller
// controller methods are plain async functions — no next parameter needed
// (asyncHandler wraps them and forwards any thrown error to next(err))
```

Never pass `next` to a controller method — error forwarding is handled by `asyncHandler`.

---

## API Versioning

All routes are prefixed with `/api/v1`. Register routers in `routes/v1.ts`:

```typescript
// routes/v1.ts
export function createV1Router(): Router {
  const router = Router()
  router.use(requireAuth) // auth for all v1 routes
  router.use('/users', createUserRouter(new UserController(...)))
  router.use('/orders', createOrderRouter(new OrderController(...)))
  return router
}

// app.ts
app.use('/api/v1', createV1Router())
```

---

## Swagger / OpenAPI (Optional)

Use `swagger-jsdoc` + `swagger-ui-express`:

```typescript
// middleware/swagger.ts
import swaggerUi from 'swagger-ui-express'
import swaggerJsdoc from 'swagger-jsdoc'

const options = {
  definition: {
    openapi: '3.0.0',
    info: { title: 'API', version: '1.0.0' },
    components: {
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
  },
  apis: ['./src/modules/**/*.router.ts'],
}

export const swaggerSpec = swaggerJsdoc(options)
// app.ts:
app.use('/docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec))
```
