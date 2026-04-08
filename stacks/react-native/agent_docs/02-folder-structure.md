# 02 · Folder Structure

The folder structure is the architecture made visible. Before reading a single line of code, a well-organized directory tree communicates what the application does, how it is divided, and where any given piece of logic lives. Avila Tek's React Native projects enforce a structure that mirrors the Clean Architecture layers at the top level and organizes the presentation layer by feature (domain concept) rather than by technical role.

This guide is prescriptive. There is no "it depends" on top-level folder names or on which layer owns which file type. Consistency across projects means engineers can orient themselves in a new codebase within minutes, not hours.

---

## Full `src/` Directory Tree

```
src/
├── app/                          # Expo Router file-based routing
│   ├── _layout.tsx               # Root layout (composition root)
│   ├── (auth)/
│   │   ├── _layout.tsx
│   │   ├── login.tsx
│   │   └── register.tsx
│   ├── (main)/
│   │   ├── _layout.tsx
│   │   ├── index.tsx             # Home tab
│   │   ├── profile/
│   │   │   ├── index.tsx
│   │   │   └── [id].tsx
│   │   └── orders/
│   │       ├── index.tsx
│   │       └── [id].tsx
│   └── +not-found.tsx
│
├── domain/
│   ├── entities/
│   │   ├── user.ts
│   │   └── order.ts
│   ├── enums/
│   │   ├── user-status.ts
│   │   └── order-status.ts
│   ├── errors/
│   │   ├── user-errors.ts
│   │   └── order-errors.ts
│   ├── repositories/
│   │   ├── i-user-repository.ts
│   │   └── i-order-repository.ts
│   ├── validators/
│   │   ├── user-validators.ts
│   │   └── order-validators.ts
│   └── index.ts
│
├── application/
│   └── use-cases/
│       ├── user/
│       │   ├── get-user-profile-use-case.ts
│       │   ├── update-user-profile-use-case.ts
│       │   └── index.ts
│       └── orders/
│           ├── create-order-use-case.ts
│           ├── get-order-use-case.ts
│           └── index.ts
│
├── infrastructure/
│   ├── data-sources/
│   │   ├── user-api-data-source.ts
│   │   ├── order-api-data-source.ts
│   │   └── secure-storage-data-source.ts
│   ├── dtos/
│   │   ├── user-dto.ts
│   │   └── order-dto.ts
│   ├── repositories/
│   │   ├── user-repository-impl.ts
│   │   └── order-repository-impl.ts
│   └── http/
│       └── axios-client.ts
│
├── presentation/
│   ├── context/
│   │   └── use-case-context.tsx
│   ├── features/
│   │   ├── user/
│   │   │   ├── screens/
│   │   │   │   ├── UserProfileScreen.tsx
│   │   │   │   └── EditUserProfileScreen.tsx
│   │   │   ├── components/
│   │   │   │   ├── UserAvatar.tsx
│   │   │   │   └── UserProfileCard.tsx
│   │   │   └── hooks/
│   │   │       ├── use-user-profile.ts
│   │   │       └── use-update-user-profile.ts
│   │   └── orders/
│   │       ├── screens/
│   │       │   ├── OrderListScreen.tsx
│   │       │   └── OrderDetailScreen.tsx
│   │       ├── components/
│   │       │   ├── OrderCard.tsx
│   │       │   └── OrderStatusBadge.tsx
│   │       └── hooks/
│   │           ├── use-orders.ts
│   │           └── use-create-order.ts
│   └── shared/
│       ├── components/
│       │   ├── Button.tsx
│       │   ├── Input.tsx
│       │   └── LoadingSpinner.tsx
│       ├── hooks/
│       │   └── use-auth-guard.ts
│       └── stores/
│           └── ui-store.ts
│
└── lib/
    ├── result.ts                 # Result<T, E> type and helpers
    ├── query-client.ts           # TanStack Query client setup
    └── constants.ts
```

---

## `app/` — Expo Router File-Based Routing

The `app/` directory is owned by **Expo Router** and follows its file-based routing conventions. Files in this directory are route definitions, not screens. They are thin wrappers that import the actual screen component from `presentation/features/`.

Route files perform two jobs: they declare the route and they render the screen. Nothing else.

```typescript
// ✅ Good — Route file is a thin wrapper
// src/app/(main)/profile/[id].tsx

import { useLocalSearchParams } from 'expo-router';
import { UserProfileScreen } from '@/presentation/features/user/screens/UserProfileScreen';

export default function UserProfileRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <UserProfileScreen userId={id} />;
}
```

```typescript
// ❌ Bad — Business logic lives in the route file
// src/app/(main)/profile/[id].tsx

import { useEffect, useState } from 'react';
import axios from 'axios';

export default function UserProfileRoute() {
  const [user, setUser] = useState(null);
  useEffect(() => {
    axios.get('/users/me').then(r => setUser(r.data)); // Logic belongs in a hook/use case
  }, []);
  return <Text>{user?.name}</Text>;
}
```

### Route Group Conventions

| Group | Purpose |
|---|---|
| `(auth)/` | Unauthenticated routes (login, register, forgot password) |
| `(main)/` | Authenticated routes with tab/drawer navigation |
| `+not-found.tsx` | 404 fallback |

---

## Barrel Exports (`index.ts`)

Barrel files aggregate exports from a directory so consumers import from the directory rather than individual files. They are useful at layer boundaries but harmful when overused.

**Use barrel exports:**
- At the root of each layer directory (`domain/index.ts`, `application/index.ts`)
- At the root of a feature's `hooks/` or `components/` subdirectory

**Do not use barrel exports:**
- Inside deeply nested subdirectories where they provide no value
- In the `app/` directory (Expo Router controls this)
- When the barrel would export more than 10–15 items (prefer explicit imports)

```typescript
// ✅ Good — Barrel at domain layer boundary
// src/domain/index.ts

export type { User } from './entities/user';
export type { Order } from './entities/order';
export type { IUserRepository } from './repositories/i-user-repository';
export * from './errors/user-errors';
```

```typescript
// ❌ Bad — Barrel that re-exports everything indiscriminately
// src/infrastructure/index.ts

export * from './data-sources/user-api-data-source';
export * from './data-sources/order-api-data-source';
export * from './repositories/user-repository-impl';
export * from './dtos/user-dto';
// This creates tight coupling and makes tree-shaking harder
```

---

## Path Aliases with `@/`

All imports use the `@/` alias resolving to `src/`. Relative imports (`../../`) are forbidden outside of the same directory level. The alias is configured in both `tsconfig.json` and `babel.config.js`.

```json
// ✅ Good — tsconfig.json path alias configuration
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

```typescript
// ✅ Good — Absolute import using alias
import type { User } from '@/domain/entities/user';
import { GetUserProfileUseCase } from '@/application/use-cases/user/get-user-profile-use-case';
import { UserProfileCard } from '@/presentation/features/user/components/UserProfileCard';
```

```typescript
// ❌ Bad — Relative import traversing multiple levels
import type { User } from '../../../domain/entities/user';
import { GetUserProfileUseCase } from '../../application/use-cases/user/get-user-profile-use-case';
```

### Import Order

Imports must be ordered:
1. External packages (React, React Native, Expo)
2. Internal absolute imports (`@/domain`, `@/application`, etc.)
3. Relative imports (same-directory files)

```typescript
// ✅ Good — Correct import order
import React, { useState } from 'react';
import { View, Text } from 'react-native';
import { useQuery } from '@tanstack/react-query';

import type { User } from '@/domain/entities/user';
import { useUseCaseContext } from '@/presentation/context/use-case-context';

import { UserAvatar } from './UserAvatar';
```

---

## Domain-per-Feature Organization

Inside `presentation/features/`, code is organized by **domain concept**, not by technical role. All screens, components, and hooks for the `user` domain live under `features/user/`. This is the opposite of organizing by `screens/`, `components/`, `hooks/` at the top level.

```
// ✅ Good — Feature-first (domain-per-feature)
presentation/features/user/
├── screens/
├── components/
└── hooks/

// ❌ Bad — Role-first (layer-per-feature)
presentation/
├── screens/
│   ├── UserProfileScreen.tsx
│   └── OrderListScreen.tsx
├── components/
│   ├── UserAvatar.tsx
│   └── OrderCard.tsx
└── hooks/
    ├── use-user-profile.ts
    └── use-orders.ts
```

Feature-first organization means that when a feature is deleted, its entire directory is deleted. There is no cross-feature cleanup required. When a feature is modified, all relevant files are in one place.

---

## Anti-Patterns

### ❌ Mixing domain concepts in a single file

```typescript
// ❌ Bad — User and Order entities in the same file
// src/domain/entities/models.ts

export interface User { id: string; name: string; }
export interface Order { id: string; total: number; }
```

Each entity belongs in its own file named after the entity.

### ❌ Importing across feature boundaries in Presentation

```typescript
// ❌ Bad — Orders feature imports from User feature components
// src/presentation/features/orders/components/OrderCard.tsx

import { UserAvatar } from '@/presentation/features/user/components/UserAvatar';
```

Shared components belong in `presentation/shared/components/`. Cross-feature component imports create hidden coupling.

---

[← Architecture](./01-architecture.md) | [Index](./README.md) | [Next: Naming Conventions →](./03-naming-conventions.md)
