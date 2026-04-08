# Enums

TypeScript `enum` declarations look appealing but carry hidden runtime costs and behavioral quirks. Numeric enums are reverse-mapped at runtime, producing larger output. String enums create nominal types that cause friction with Zod, serialization libraries, and API response validation. The TypeScript team itself has advised caution with enums and the ecosystem has largely moved toward alternatives.

Avila Tek uses two patterns instead of TypeScript enums: the `const` object pattern (for when you need a runtime-accessible map of values) and string literal union types (for when you only need the type). Both patterns are tree-shakeable, generate minimal runtime code, and integrate naturally with Zod.

---

## The `const` Object Pattern

A `const` object creates a plain JavaScript object with `as const` to infer literal types. The corresponding union type is derived with `typeof` and `keyof`.

```typescript
// ✅ Good — const object with derived type
// src/domain/enums/user-status.ts

export const UserStatus = {
  ACTIVE: 'ACTIVE',
  INACTIVE: 'INACTIVE',
  SUSPENDED: 'SUSPENDED',
  PENDING_VERIFICATION: 'PENDING_VERIFICATION',
} as const;

export type UserStatus = (typeof UserStatus)[keyof typeof UserStatus];
```

This gives you both a runtime value (`UserStatus.ACTIVE`) and a type (`UserStatus`). The name collision between the object and the type is intentional — TypeScript resolves them in the correct context.

```typescript
// ✅ Good — Usage of const object pattern
import { UserStatus } from '@/domain/enums/user-status';
import type { UserStatus as UserStatusType } from '@/domain/enums/user-status';

// Runtime access (e.g., displaying in a dropdown):
const statuses = Object.values(UserStatus); // ['ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION']

// Type usage on an entity:
export interface User {
  readonly status: UserStatusType;
}

// Comparison:
if (user.status === UserStatus.ACTIVE) {
  // ...
}
```

---

## String Literal Union Types

When runtime access to the values is not needed, a string literal union is simpler and more explicit:

```typescript
// ✅ Good — String literal union for domain-only typing
// src/domain/enums/order-status.ts

export type OrderStatus =
  | 'PENDING'
  | 'PROCESSING'
  | 'SHIPPED'
  | 'DELIVERED'
  | 'CANCELLED'
  | 'REFUNDED';
```

```typescript
// ✅ Good — Using the union in an entity
import type { OrderStatus } from '@/domain/enums/order-status';

export interface Order {
  readonly id: string;
  readonly status: OrderStatus;
}

// Exhaustive switch on OrderStatus:
function getOrderStatusLabel(status: OrderStatus): string {
  switch (status) {
    case 'PENDING':      return 'Pending';
    case 'PROCESSING':   return 'Processing';
    case 'SHIPPED':      return 'Shipped';
    case 'DELIVERED':    return 'Delivered';
    case 'CANCELLED':    return 'Cancelled';
    case 'REFUNDED':     return 'Refunded';
    // TypeScript will error if a case is missing
  }
}
```

---

## TypeScript `enum` — Never Use

```typescript
// ❌ Bad — TypeScript numeric enum (avoid entirely)
enum UserStatus {
  Active,      // 0 at runtime — not what your API sends
  Inactive,    // 1 at runtime
  Suspended,   // 2 at runtime
}

// ❌ Bad — TypeScript string enum (still avoid)
enum OrderStatus {
  Pending = 'PENDING',
  Processing = 'PROCESSING',
}

// Problems with string enums:
// - OrderStatus.Pending !== 'PENDING' in some strict nominal type checks
// - Cannot iterate values without Object.values(OrderStatus) returning unexpected results
// - Zod z.nativeEnum() works but is more verbose than z.enum()
// - Produces more output than necessary in compiled code
```

---

## Naming Rules

| Rule | Example |
|---|---|
| PascalCase for `const` object name | `UserStatus`, `OrderStatus` |
| No `Enum` suffix | `UserStatus` not `UserStatusEnum` |
| PascalCase for union type alias | `UserStatus`, `OrderStatus` |
| `SCREAMING_SNAKE_CASE` for values | `'PENDING_VERIFICATION'`, `'IN_PROGRESS'` |

```typescript
// ✅ Good
export const UserStatus = { ACTIVE: 'ACTIVE', INACTIVE: 'INACTIVE' } as const;
export type UserStatus = (typeof UserStatus)[keyof typeof UserStatus];

// ❌ Bad — Enum suffix
export const UserStatusEnum = { ... } as const;
export type UserStatusEnum = ...;
```

---

## Zod Integration

Zod's `z.enum()` works directly with string literal tuples, aligning perfectly with the string literal union pattern:

```typescript
// ✅ Good — Zod schema using z.enum() with const object
// src/domain/validators/user-validators.ts

import { z } from 'zod';
import { UserStatus } from '@/domain/enums/user-status';

// Derive the tuple from the const object for Zod:
const userStatusValues = Object.values(UserStatus) as [string, ...string[]];

export const userStatusSchema = z.enum(
  userStatusValues as [UserStatus, ...UserStatus[]]
);

// Or inline for simpler enums:
export const orderStatusSchema = z.enum([
  'PENDING',
  'PROCESSING',
  'SHIPPED',
  'DELIVERED',
  'CANCELLED',
  'REFUNDED',
]);
```

---

## DTO Enums vs Domain Enums

API responses may use different casing or naming than your domain model. The DTO layer is responsible for mapping API values to domain enum values. The domain enum must not be shaped to fit the API.

```typescript
// ✅ Good — DTO maps API value to domain enum
// src/infrastructure/dtos/user-dto.ts

import { UserStatus } from '@/domain/enums/user-status';

// API sends: { "account_status": "active" } (lowercase)
// Domain expects: UserStatus.ACTIVE ('ACTIVE')

function mapApiStatusToDomain(apiStatus: string): UserStatus {
  const map: Record<string, UserStatus> = {
    active: UserStatus.ACTIVE,
    inactive: UserStatus.INACTIVE,
    suspended: UserStatus.SUSPENDED,
    pending_verification: UserStatus.PENDING_VERIFICATION,
  };
  return map[apiStatus] ?? UserStatus.INACTIVE;
}
```

```typescript
// ❌ Bad — Domain enum shaped to match API casing
export const UserStatus = {
  active: 'active',       // lowercase to match API — domain reflects API, not business model
  inactive: 'inactive',
} as const;
```

---

## Anti-Patterns

### ❌ Magic strings instead of enums

```typescript
// ❌ Bad — Raw string literals scattered across the codebase
if (user.status === 'active') { ... }       // Typo risk, not refactorable
if (order.status === 'PNEDING') { ... }     // Typo that TypeScript cannot catch
```

Use the `const` object pattern or string literal union. TypeScript will catch typos and enable exhaustive checks.

### ❌ Numeric values for business concepts

```typescript
// ❌ Bad — Numeric enum values for a business concept
export const OrderStatus = {
  PENDING: 0,
  PROCESSING: 1,
  SHIPPED: 2,
} as const;

// Logs, API responses, and debugger views show '1' not 'PROCESSING'
```

---

[← Entities](./entities.md) | [Index](../README.md) | [Next: Repository Interfaces →](./repositories.md)
