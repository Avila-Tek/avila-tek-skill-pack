# 01 · Architecture

Clean Architecture is the structural law of every Avila Tek React Native application. It is not a suggestion or a loose guideline — it is the rule that every file, import, and dependency must comply with. The architecture separates the codebase into four concentric layers, each with a clearly defined purpose and a strict set of allowed dependencies. The further inward a layer sits, the more stable and abstract it is.

The practical payoff is significant. Business rules can be tested without spinning up a device, a network, or a navigation stack. Infrastructure can be swapped (replace REST with GraphQL, replace AsyncStorage with SQLite) without touching a single use case. UI frameworks come and go; a well-structured domain layer survives them. Engineers joining the project find the same architectural pattern regardless of which feature they open.

---

## The Four Layers

```
┌─────────────────────────────────────────────────────────┐
│                    PRESENTATION                          │
│        Screens · Components · Hooks · Navigation         │
│                   (React Native, Expo)                   │
├─────────────────────────────────────────────────────────┤
│                   INFRASTRUCTURE                         │
│      Data Sources · Repository Impls · DTOs · HTTP       │
│              (Axios, AsyncStorage, Expo APIs)             │
├─────────────────────────────────────────────────────────┤
│                    APPLICATION                           │
│              Use Cases · Orchestration                   │
│                   (Pure TypeScript)                      │
├─────────────────────────────────────────────────────────┤
│                      DOMAIN                              │
│      Entities · Repository Interfaces · Errors           │
│             Validators · Value Objects                   │
│                   (Pure TypeScript)                      │
└─────────────────────────────────────────────────────────┘

         Dependencies flow INWARD only:
         Presentation → Infrastructure → Application → Domain
```

---

## The Dependency Rule

The single most important rule: **a layer may only import from layers that are more inward than itself.** Domain imports nothing from the project. Application imports only from Domain. Infrastructure imports from Domain (to implement interfaces). Presentation imports from Application and Infrastructure (for DI) and Domain (for types).

```typescript
// ✅ Good — Application depends on Domain interface (inward)
import type { IUserRepository } from '@/domain/repositories/user-repository';

// ❌ Bad — Domain depends on Infrastructure (outward)
import { UserApiDataSource } from '@/infrastructure/data-sources/user-api';
```

Violations of the dependency rule are the single most destructive thing an engineer can introduce into a Clean Architecture codebase. A single outward import in the domain layer collapses the boundary that makes testing and replacement possible.

---

## Domain-Driven Design Concepts

### Domain

The domain is the heart of the application. It models the real-world concepts your software is built around — users, orders, invoices, products. It answers the question: "What does this application do?" without answering "How does it do it?"

### Bounded Context

A bounded context defines the scope in which a particular domain model applies. In a React Native app, each top-level feature folder (`user/`, `orders/`, `billing/`) represents a bounded context. Entities from one context do not bleed into another.

### Entity

An entity is a domain object with a persistent identity. A `User` entity has an `id` that distinguishes one user from another even if all their other fields are identical. Entities are defined as readonly TypeScript interfaces or classes in the domain layer.

### Repository

A repository is a collection-like abstraction over a data store. The domain layer defines the **interface** (the contract). The infrastructure layer provides the **implementation**. This inversion of dependency is what makes the domain independent of persistence technology.

### Use Case

A use case represents a single piece of application behavior. `GetUserProfileUseCase`, `CreateOrderUseCase`, `LogoutUseCase` — each encapsulates one workflow. Use cases live in the application layer, depend on domain interfaces, and are invoked by presentation hooks.

---

## Layer Responsibilities

### Domain — CAN and CANNOT

| CAN | CANNOT |
|---|---|
| Define entity interfaces | Import from React Native |
| Define repository interfaces | Import from Expo |
| Define domain error types | Make HTTP calls |
| Define Zod validators | Access AsyncStorage |
| Define value objects | Know about UI state |

### Application — CAN and CANNOT

| CAN | CANNOT |
|---|---|
| Import domain interfaces and types | Import from React Native |
| Orchestrate multiple repositories | Know about HTTP or persistence |
| Transform domain data | Import Zustand or TanStack Query |
| Return `Result<T, E>` | Render anything |

### Infrastructure — CAN and CANNOT

| CAN | CANNOT |
|---|---|
| Implement domain repository interfaces | Contain business logic |
| Import HTTP clients (Axios, fetch) | Import from Presentation |
| Import Expo storage APIs | Return raw API responses to Application |
| Map DTOs to domain entities | Throw uncaught exceptions outward |

### Presentation — CAN and CANNOT

| CAN | CANNOT |
|---|---|
| Import React Native and Expo components | Call infrastructure directly |
| Use TanStack Query and Zustand | Contain business logic |
| Invoke use cases via hooks | Import Axios or data sources |
| Use Expo Router for navigation | Bypass the application layer |

---

## Dependency Injection with React Context

The composition root is where the concrete implementations are wired to the domain interfaces. In a React Native app, the composition root is a React Context Provider near the root of the application tree. Use cases receive repository implementations through constructor injection.

```typescript
// ✅ Good — Composition root wires concrete implementations
// src/app/_layout.tsx (Expo Router root layout)

import React from 'react';
import { UserRepositoryImpl } from '@/infrastructure/repositories/user-repository-impl';
import { UserApiDataSource } from '@/infrastructure/data-sources/user-api-data-source';
import { GetUserProfileUseCase } from '@/application/use-cases/get-user-profile-use-case';
import { UseCaseContext } from '@/presentation/context/use-case-context';

export default function RootLayout() {
  const userDataSource = new UserApiDataSource();
  const userRepository = new UserRepositoryImpl(userDataSource);
  const getUserProfile = new GetUserProfileUseCase(userRepository);

  return (
    <UseCaseContext.Provider value={{ getUserProfile }}>
      <Stack />
    </UseCaseContext.Provider>
  );
}
```

```typescript
// ✅ Good — Use case context definition
// src/presentation/context/use-case-context.ts

import { createContext, useContext } from 'react';
import type { GetUserProfileUseCase } from '@/application/use-cases/get-user-profile-use-case';

interface UseCaseContextValue {
  getUserProfile: GetUserProfileUseCase;
}

export const UseCaseContext = createContext<UseCaseContextValue | null>(null);

export function useUseCaseContext(): UseCaseContextValue {
  const ctx = useContext(UseCaseContext);
  if (!ctx) throw new Error('useUseCaseContext must be used inside UseCaseContext.Provider');
  return ctx;
}
```

```typescript
// ❌ Bad — Presentation instantiates infrastructure directly
// src/presentation/hooks/use-user-profile.ts

import { UserRepositoryImpl } from '@/infrastructure/repositories/user-repository-impl';
import { UserApiDataSource } from '@/infrastructure/data-sources/user-api-data-source';

// This bypasses DI and makes the hook impossible to test without network
const repo = new UserRepositoryImpl(new UserApiDataSource());
```

---

## Data Flow

The unidirectional data flow through the layers looks like this:

```
User Action (tap button)
       │
       ▼
  Presentation Hook
  (calls use case via context)
       │
       ▼
  Application Use Case
  (execute() method)
       │
       ▼
  Domain Repository Interface
  (IUserRepository.findById())
       │
       ▼
  Infrastructure Repository Impl
  (fetches, maps DTO → Entity)
       │
       ▼
  Returns Result<Entity, DomainError>
       │
  (bubbles back up each layer)
       │
       ▼
  Presentation re-renders with data
```

No step skips a layer. Presentation never calls infrastructure directly. Use cases never import HTTP clients.

---

## Anti-Patterns

### ❌ Fat screens that contain business logic

```typescript
// ❌ Bad — Screen performs business logic inline
export default function CheckoutScreen() {
  const handleCheckout = async () => {
    const response = await axios.post('/orders', { items });
    if (response.data.status === 'pending') {
      // Business rule: pending orders need confirmation
      await axios.patch(`/orders/${response.data.id}/confirm`);
    }
  };
}
```

Business logic belongs in a use case. The screen's only job is to invoke a hook and render the result.

### ❌ Domain importing infrastructure

```typescript
// ❌ Bad — Entity knows about serialization library
import { plainToClass } from 'class-transformer';

export class User {
  static fromPlain(data: unknown): User {
    return plainToClass(User, data); // Domain should not know about class-transformer
  }
}
```

### ❌ Use case importing HTTP client

```typescript
// ❌ Bad — Application layer bypasses repository abstraction
import axios from 'axios';

export class GetUserProfileUseCase {
  async execute(id: string) {
    const { data } = await axios.get(`/users/${id}`); // Violates dependency rule
    return data;
  }
}
```

---

[← Index](./README.md) | [Index](./README.md) | [Next: Folder Structure →](./02-folder-structure.md)
