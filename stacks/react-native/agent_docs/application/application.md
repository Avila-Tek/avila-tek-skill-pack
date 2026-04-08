# Application Layer

The application layer is the orchestrator. It sits between the domain — which defines what things are — and the infrastructure — which defines how things are stored and retrieved. The application layer answers the question: "What does the application *do*?" Each use case represents one answer to that question.

The application layer is the only layer that actively coordinates multiple domain concepts. A checkout use case might coordinate the user repository, the order repository, and the payment service interface. That coordination is the application layer's sole purpose. It does not know about HTTP. It does not know about React Native. It holds no UI state and renders nothing.

---

## What the Application Layer Contains

```
src/application/
└── use-cases/
    ├── user/
    │   ├── get-user-profile-use-case.ts
    │   ├── update-user-profile-use-case.ts
    │   ├── delete-account-use-case.ts
    │   └── index.ts
    ├── auth/
    │   ├── login-use-case.ts
    │   ├── logout-use-case.ts
    │   ├── register-use-case.ts
    │   └── index.ts
    └── orders/
        ├── create-order-use-case.ts
        ├── get-order-use-case.ts
        ├── cancel-order-use-case.ts
        └── index.ts
```

The application layer contains **only use cases**. There are no services, no managers, no utilities. If a piece of logic does not directly implement a user-facing action, it either belongs in the domain (as a pure function on entities) or it does not belong in the application layer at all.

---

## Absolute Constraints

The application layer must never contain:

- `import from 'react'` or `import from 'react-native'`
- `import from 'expo-*'`
- Direct imports of data sources, HTTP clients, or storage
- Zustand stores or TanStack Query hooks
- Any rendering or JSX

The application layer may only import from:

- Domain layer (`@/domain/**`)
- The `Result` helper (`@/lib/result`)
- Other application types (shared input/output types)

```typescript
// ✅ Good — Application only imports from domain
import type { IUserRepository } from '@/domain/repositories/i-user-repository';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';
import { ok, err } from '@/lib/result';
```

```typescript
// ❌ Bad — Application importing infrastructure or presentation
import { UserRepositoryImpl } from '@/infrastructure/repositories/user-repository-impl';
import { useQuery } from '@tanstack/react-query';
import { useAuthStore } from '@/presentation/shared/stores/auth-store';
```

---

## Depends Only on Domain Interfaces

Use cases receive their dependencies through constructor injection. The type of each dependency is a domain interface (`IUserRepository`, `IOrderRepository`), never a concrete class. This is what makes use cases testable with mock repositories and what enforces the dependency rule.

```typescript
// ✅ Good — Use case depends on domain interfaces only
export class CreateOrderUseCase {
  constructor(
    private readonly userRepository: IUserRepository,
    private readonly orderRepository: IOrderRepository,
  ) {}
}
```

---

## Layer Pages

- [Use Cases](./use-cases.md) — Class pattern, `execute()`, naming, orchestration

---

[← Validators](../domain/validators.md) | [Index](../README.md) | [Next: Use Cases →](./use-cases.md)
