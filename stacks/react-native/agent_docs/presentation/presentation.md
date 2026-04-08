# Presentation Layer

The presentation layer is everything the user sees and interacts with. It is composed of screens (top-level route views), components (reusable UI building blocks), and hooks (state and behavior managers that connect screens and components to the application layer). It uses React Native, Expo, NativeWind, Expo Router, TanStack Query, and Zustand.

The presentation layer is the only layer that is permitted to import from React Native and Expo. It is also the only layer that directly invokes use cases — but only through custom hooks, never directly in components or screens. The presentation layer is the outermost ring: it knows about everything below it, but nothing below it knows about the presentation layer.

---

## What the Presentation Layer Contains

```
src/presentation/
├── context/
│   └── use-case-context.tsx       # Composition root context
├── features/
│   ├── user/
│   │   ├── screens/
│   │   ├── components/
│   │   └── hooks/
│   └── orders/
│       ├── screens/
│       ├── components/
│       └── hooks/
└── shared/
    ├── components/                # Cross-feature reusable components
    ├── hooks/                     # Cross-feature hooks
    └── stores/                    # Zustand stores
```

---

## No Direct Infrastructure Calls

The presentation layer never imports from `@/infrastructure`. It interacts with the application layer exclusively through custom hooks that wrap TanStack Query. The use cases are provided through React Context (the composition root pattern described in the architecture guide).

```typescript
// ✅ Good — Presentation hook uses use case via context
import { useUseCaseContext } from '@/presentation/context/use-case-context';

export function useUserProfile(userId: string) {
  const { getUserProfile } = useUseCaseContext();
  // ...
}
```

```typescript
// ❌ Bad — Screen imports infrastructure directly
import { UserRepositoryImpl } from '@/infrastructure/repositories/user-repository-impl';
import { UserApiDataSource } from '@/infrastructure/data-sources/user-api-data-source';
```

---

## Expo Router for Navigation

Navigation is handled exclusively through Expo Router. Hooks and components do not call `navigate()` directly — navigation is triggered from screens (as event handlers from component callbacks) or from hooks (after successful mutations).

```typescript
// ✅ Good — Navigation triggered from hook after mutation success
import { router } from 'expo-router';

export function useLogin() {
  return useMutation({
    mutationFn: ...,
    onSuccess: (result) => {
      if (result.success) router.replace('/(main)');
    },
  });
}
```

---

## Layer Pages

- [Features](./features/features.md) — Vertical slice structure
- [Screens](./features/screens.md) — Expo Router conventions, Screen vs View
- [Components](./features/components.md) — Pure/presentational, NativeWind, props
- [Hooks](./hooks/hooks.md) — TanStack Query wrappers, use case composition

---

[← Repository Implementations](../infrastructure/repositories.md) | [Index](../README.md) | [Next: Features →](./features/features.md)
