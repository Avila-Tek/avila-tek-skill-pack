# Entities

An entity is a domain object defined by its **identity**, not by its attribute values. Two users with identical names and emails are still different entities if their `id` fields differ. This identity-based equality distinguishes entities from value objects, which are defined entirely by their values.

Entities in Avila Tek's codebase are **readonly TypeScript interfaces**. They hold no behavior beyond computed getters, carry no serialization methods, and import nothing from outside the domain layer. They are the stable vocabulary of the application — the nouns around which all use cases are written.

---

## Readonly TypeScript Interfaces

All entity fields must be `readonly`. Entities are never mutated in place. When a field needs to change, the application layer creates a new object with the updated value.

```typescript
// ✅ Good — Readonly interface with clear domain fields
// src/domain/entities/user.ts

export interface User {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly avatarUrl: string | null;
  readonly status: UserStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}
```

```typescript
// ✅ Good — Order entity with nested value types
// src/domain/entities/order.ts

export interface OrderItem {
  readonly productId: string;
  readonly quantity: number;
  readonly unitPrice: number;
}

export interface Order {
  readonly id: string;
  readonly userId: string;
  readonly items: ReadonlyArray<OrderItem>;
  readonly status: OrderStatus;
  readonly totalAmount: number;
  readonly createdAt: Date;
}
```

```typescript
// ❌ Bad — Mutable entity fields
export interface User {
  id: string;       // Missing readonly — can be reassigned
  email: string;    // Missing readonly
  name: string;
}
```

```typescript
// ❌ Bad — Entity as a class with mutation methods
export class User {
  id: string;
  name: string;

  rename(newName: string): void {
    this.name = newName; // Mutation in place — violates immutability
  }
}
```

---

## No Serialization Methods on Entities

Entities do not know how to serialize themselves. They do not have `toJSON()`, `toDto()`, `toApiPayload()`, or similar methods. Serialization is the responsibility of DTOs in the infrastructure layer.

```typescript
// ✅ Good — Entity is a plain data type, no serialization
export interface User {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly createdAt: Date;
}
```

```typescript
// ❌ Bad — Entity contains serialization logic
export interface User {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly createdAt: Date;
  toApiPayload(): { id: string; full_name: string; email_address: string }; // Belongs in DTO
  toJSON(): string; // Belongs in infrastructure
}
```

---

## Computed Getters

Pure, derived values calculated from existing entity fields are allowed as standalone utility functions co-located with the entity. If using a class-based approach, computed getters are permitted but mutation methods are not.

```typescript
// ✅ Good — Computed values as standalone utility functions
// src/domain/entities/order.ts

export interface Order {
  readonly id: string;
  readonly items: ReadonlyArray<OrderItem>;
  readonly status: OrderStatus;
  readonly createdAt: Date;
}

export function getOrderTotal(order: Order): number {
  return order.items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);
}

export function isOrderCancellable(order: Order): boolean {
  return order.status === 'PENDING' || order.status === 'PROCESSING';
}
```

```typescript
// ✅ Good — Class entity with computed getters only (no mutation)
export class Order {
  constructor(
    public readonly id: string,
    public readonly items: ReadonlyArray<OrderItem>,
    public readonly status: OrderStatus,
    public readonly createdAt: Date,
  ) {}

  get total(): number {
    return this.items.reduce((sum, item) => sum + item.unitPrice * item.quantity, 0);
  }

  get isCancellable(): boolean {
    return this.status === 'PENDING' || this.status === 'PROCESSING';
  }
}
```

---

## The `empty()` Factory Pattern

The `empty()` factory provides a safe, consistent default instance of an entity. It is used in forms, optimistic updates, and tests where a valid but blank entity is needed. It is a static factory function, not a class method.

```typescript
// ✅ Good — empty() factory for default values
// src/domain/entities/user.ts

import type { UserStatus } from '@/domain/enums/user-status';

export interface User {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly avatarUrl: string | null;
  readonly status: UserStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export function emptyUser(): User {
  return {
    id: '',
    email: '',
    displayName: '',
    avatarUrl: null,
    status: 'ACTIVE',
    createdAt: new Date(0),
    updatedAt: new Date(0),
  };
}
```

```typescript
// ✅ Good — Usage of empty() in a form hook default state
import { emptyUser } from '@/domain/entities/user';

const [formState, setFormState] = useState(emptyUser());
```

```typescript
// ❌ Bad — Nullable entity type instead of empty factory
interface UseUserFormResult {
  user: User | null; // Forces null checks everywhere
}

// ✅ Better:
interface UseUserFormResult {
  user: User; // Always a valid User, empty() when uninitialized
}
```

---

## Naming Rules

| Rule | Example |
|---|---|
| Singular noun, PascalCase | `User`, `Order`, `ProductVariant` |
| No `Entity` suffix | `User` not `UserEntity` |
| No `Model` suffix | `Order` not `OrderModel` |
| No `Data` suffix | `Profile` not `ProfileData` |

```typescript
// ✅ Good — Clean entity names
export interface User { ... }
export interface Order { ... }
export interface ProductVariant { ... }
export interface ShippingAddress { ... }
```

```typescript
// ❌ Bad — Noisy suffixes that add no meaning
export interface UserEntity { ... }
export interface OrderModel { ... }
export interface ProductVariantData { ... }
```

---

## Anti-Patterns

### ❌ Entity importing from infrastructure

```typescript
// ❌ Bad — Entity knows about persistence
import { Column, Entity as OrmEntity, PrimaryColumn } from 'typeorm';

@OrmEntity()
export class User {
  @PrimaryColumn()
  id: string;

  @Column()
  email: string;
}
```

ORM decorators, persistence annotations, and serialization attributes have no place in domain entities.

### ❌ Mutable arrays on entities

```typescript
// ❌ Bad — Mutable array allows in-place modification
export interface Order {
  readonly id: string;
  items: OrderItem[]; // Missing readonly — array can be pushed to
}

// ✅ Good:
export interface Order {
  readonly id: string;
  readonly items: ReadonlyArray<OrderItem>;
}
```

---

[← Domain Layer](./domain.md) | [Index](../README.md) | [Next: Enums →](./enums.md)
