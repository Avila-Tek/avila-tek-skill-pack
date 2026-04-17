---
description: JWT authentication in Express — requireAuth middleware, TypeScript module augmentation, requireRole factory, and protecting routers.
globs: ["src/middleware/auth.middleware.ts", "src/types/express.d.ts", "src/modules/**/*.ts"]
alwaysApply: false
---

# Authentication

## JWT Pattern

```
Client → Authorization: Bearer <token>
  → requireAuth middleware
    → verify JWT signature
    → extract claims
    → attach to req.user
      → controller accesses req.user
```

Token payload shape:

```typescript
export interface JwtPayload {
  sub: string     // user ID
  email: string
  role: 'admin' | 'member'
  iat: number
  exp: number
}
```

---

## TypeScript Module Augmentation

You **must** declare `req.user` before accessing it — otherwise TypeScript types it as `any`.

```typescript
// src/types/express.d.ts
import type { JwtPayload } from '../shared/types/jwt-payload'

declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload
    }
  }
}
```

Ensure `tsconfig.json` includes this file in its compilation scope.

---

## `requireAuth` Middleware

```typescript
// middleware/auth.middleware.ts
import { Request, Response, NextFunction } from 'express'
import jwt from 'jsonwebtoken'
import { UnauthorizedError } from '../shared/errors/unauthorized-error'
import type { JwtPayload } from '../shared/types/jwt-payload'

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const header = req.headers.authorization
  if (!header?.startsWith('Bearer ')) {
    next(new UnauthorizedError('Missing Bearer token'))
    return
  }

  const token = header.slice(7)
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!) as JwtPayload
    req.user = payload
    next()
  } catch {
    next(new UnauthorizedError('Invalid or expired token'))
  }
}
```

---

## `requireRole` Factory

```typescript
// middleware/auth.middleware.ts (continued)
import { ForbiddenError } from '../shared/errors/forbidden-error'

export function requireRole(role: JwtPayload['role']) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      next(new UnauthorizedError())
      return
    }
    if (req.user.role !== role) {
      next(new ForbiddenError())
      return
    }
    next()
  }
}
```

---

## Applying Auth to Routers

```typescript
// routes/v1.ts — protect all v1 routes
import { Router } from 'express'
import { requireAuth } from '../middleware/auth.middleware'

export function createV1Router(): Router {
  const router = Router()
  router.use(requireAuth) // applies to all routes mounted below
  router.use('/users', createUserRouter(...))
  router.use('/orders', createOrderRouter(...))
  return router
}
```

For mixed public/protected APIs, apply auth per-router instead of globally:

```typescript
// app.ts — public routes outside v1, protected inside
app.use('/api/auth', createAuthRouter())      // no requireAuth
app.use('/api/health', createHealthRouter()) // no requireAuth
app.use('/api/v1', requireAuth, createV1Router()) // protected
app.use(errorHandler)
```

---

## Per-Route Role Guard

```typescript
// users.router.ts
import { requireAuth, requireRole } from '../../middleware/auth.middleware'

const router = Router()

// Any authenticated user
router.get('/:id', asyncHandler(controller.findById))

// Admin only
router.delete('/:id', requireRole('admin'), asyncHandler(controller.remove))

// Multiple roles
router.patch('/:id/approve', requireRole('admin'), asyncHandler(controller.approve))
```

---

## Token Issuance (Login Route)

```typescript
// modules/auth/auth.controller.ts
export class AuthController {
  login = async (req: Request, res: Response): Promise<void> => {
    const { email, password } = req.body as LoginDto
    const user = await this.authService.validateCredentials(email, password)
    const token = jwt.sign(
      { sub: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET!,
      { expiresIn: '15m' },
    )
    res.json({ accessToken: token })
  }
}
```

---

## Accessing `req.user` in Controllers

```typescript
export class UserController {
  findById = async (req: Request, res: Response): Promise<void> => {
    // req.user is JwtPayload | undefined
    // After requireAuth middleware, it is always defined — safe to assert
    const currentUser = req.user!
    const user = await this.service.findById(req.params.id, currentUser)
    res.json(toUserResponse(user))
  }
}
```

---

## Anti-Patterns

```typescript
// ❌ Accessing req.user without module augmentation — implicit any
const userId = req.user.sub // TypeScript error or unsafe any

// ✅ Declare in express.d.ts first
// req.user is now JwtPayload | undefined
```

```typescript
// ❌ Catching JWT error and continuing — silent auth bypass
export function requireAuth(req, res, next) {
  try {
    req.user = jwt.verify(token, secret)
    next()
  } catch {
    next() // wrong! treats invalid tokens as unauthenticated, not unauthorized
  }
}

// ✅ Forward error to errorHandler
} catch {
  next(new UnauthorizedError('Invalid or expired token'))
}
```

```typescript
// ❌ Hardcoding JWT_SECRET
const token = jwt.sign(payload, 'my-secret') // never hardcode

// ✅ From environment (validated at startup with Zod)
const token = jwt.sign(payload, process.env.JWT_SECRET!)
```

```typescript
// ❌ requireAuth inside the controller — wrong layer
export class UserController {
  findById = async (req: Request, res: Response) => {
    if (!req.headers.authorization) return res.status(401).json(...)
    // ...
  }
}

// ✅ Auth is a middleware concern — apply in the router
router.get('/:id', requireAuth, asyncHandler(controller.findById))
```
