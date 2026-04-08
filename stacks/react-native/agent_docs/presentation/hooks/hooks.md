# Hooks

Custom hooks are the behavioral layer of the presentation. They are the React equivalent of a BLoC (Business Logic Component) — they encapsulate state, trigger use case execution, and expose a typed interface to screens and components. Screens call hooks. Hooks call use cases. Use cases call repositories. This chain keeps each layer focused and testable.

The hook is the only place in the presentation layer where `useQuery`, `useMutation`, and `useUseCaseContext` appear. Screens and components never call these directly. A screen that wires its own TanStack Query calls has coupling to the query layer that makes it harder to test, refactor, or reuse. A hook that encapsulates the same logic is an injectable, nameable, composable unit.

---

## Hooks as the Behavioral Layer

```
Screen (renders)
  └── calls Hook (manages state & behavior)
        └── calls Use Case (via context)
              └── calls Repository Interface (domain contract)
                    └── implemented by Repository Impl (infrastructure)
```

---

## Wrapping `useQuery` for Data Fetching

```typescript
// ✅ Good — Hook wrapping useQuery with use case execution
// src/presentation/features/user/hooks/use-user-profile.ts

import { useQuery } from '@tanstack/react-query';
import { useUseCaseContext } from '@/presentation/context/use-case-context';
import type { User } from '@/domain/entities/user';
import type { UserError } from '@/domain/errors/user-errors';

interface UseUserProfileResult {
  user: User | undefined;
  error: UserError | null;
  isLoading: boolean;
  refetch: () => void;
}

export function useUserProfile(userId: string): UseUserProfileResult {
  const { getUserProfile } = useUseCaseContext();

  const query = useQuery({
    queryKey: ['users', 'detail', userId],
    queryFn: async () => {
      const result = await getUserProfile.execute(userId);
      if (!result.success) throw result.error;
      return result.data;
    },
    enabled: Boolean(userId),
  });

  return {
    user: query.data,
    error: query.error as UserError | null,
    isLoading: query.isLoading,
    refetch: query.refetch,
  };
}
```

---

## Wrapping `useMutation` for Write Operations

```typescript
// ✅ Good — Hook wrapping useMutation for a write operation
// src/presentation/features/user/hooks/use-update-user-profile.ts

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { router } from 'expo-router';
import { useUseCaseContext } from '@/presentation/context/use-case-context';
import { useUiStore } from '@/presentation/shared/stores/ui-store';
import type { UpdateProfileInput } from '@/domain/validators/user-validators';
import type { UserError } from '@/domain/errors/user-errors';
import type { User } from '@/domain/entities/user';

interface UseUpdateUserProfileResult {
  updateProfile: (input: UpdateProfileInput) => void;
  isLoading: boolean;
  error: UserError | null;
}

export function useUpdateUserProfile(userId: string): UseUpdateUserProfileResult {
  const { updateUserProfile } = useUseCaseContext();
  const queryClient = useQueryClient();
  const addToast = useUiStore((s) => s.addToast);

  const mutation = useMutation({
    mutationFn: async (input: UpdateProfileInput) => {
      const result = await updateUserProfile.execute(userId, input);
      if (!result.success) throw result.error;
      return result.data;
    },
    onSuccess: (updatedUser: User) => {
      queryClient.setQueryData(['users', 'detail', userId], updatedUser);
      addToast({ message: 'Profile updated successfully', type: 'success' });
      router.back();
    },
    onError: (error: UserError) => {
      addToast({
        message: error.type === 'USER_NETWORK_ERROR' ? 'Network error. Try again.' : 'Update failed.',
        type: 'error',
      });
    },
  });

  return {
    updateProfile: mutation.mutate,
    isLoading: mutation.isPending,
    error: mutation.error as UserError | null,
  };
}
```

---

## Hook Naming Convention

| Pattern | Convention | Example |
|---|---|---|
| Fetching a single resource | `use[Resource]` or `useGet[Resource]` | `useUserProfile`, `useGetOrder` |
| Fetching a list | `use[Resources]` or `useGet[Resources]` | `useOrders`, `useGetOrders` |
| Creating a resource | `useCreate[Resource]` | `useCreateOrder` |
| Updating a resource | `useUpdate[Resource]` | `useUpdateUserProfile` |
| Deleting a resource | `useDelete[Resource]` | `useDeleteAccount` |
| Authentication action | `useLogin`, `useLogout`, `useRegister` | — |

---

## Hook Composition

Hooks can call other hooks. This is the mechanism for sharing behavior across features without creating cross-feature component dependencies.

```typescript
// ✅ Good — Hook composing other hooks
// src/presentation/shared/hooks/use-auth-guard.ts

import { useEffect } from 'react';
import { router } from 'expo-router';
import { useAuthStore } from '@/presentation/shared/stores/auth-store';

export function useAuthGuard() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);

  useEffect(() => {
    if (!isAuthenticated) {
      router.replace('/(auth)/login');
    }
  }, [isAuthenticated]);

  return { isAuthenticated };
}
```

```typescript
// ✅ Good — Screen hook composing multiple domain hooks
// src/presentation/features/orders/hooks/use-order-detail-screen.ts

import { useOrderDetail } from './use-order-detail';
import { useCancelOrder } from './use-cancel-order';
import { useAuthGuard } from '@/presentation/shared/hooks/use-auth-guard';

export function useOrderDetailScreen(orderId: string) {
  useAuthGuard();
  const { order, isLoading, error } = useOrderDetail(orderId);
  const { cancelOrder, isCancelling } = useCancelOrder(orderId);

  return { order, isLoading, error, cancelOrder, isCancelling };
}
```

---

## Full Example: `useUserProfile` with List Fetching

```typescript
// ✅ Good — Hook for a list with filters and pagination
// src/presentation/features/orders/hooks/use-orders.ts

import { useQuery } from '@tanstack/react-query';
import { useUseCaseContext } from '@/presentation/context/use-case-context';
import { useAuthStore } from '@/presentation/shared/stores/auth-store';
import type { Order } from '@/domain/entities/order';
import type { OrderError } from '@/domain/errors/order-errors';

interface UseOrdersResult {
  orders: Order[];
  isLoading: boolean;
  error: OrderError | null;
  refetch: () => void;
}

export function useOrders(): UseOrdersResult {
  const { getOrders } = useUseCaseContext();
  const userId = useAuthStore((s) => s.userId);

  const query = useQuery({
    queryKey: ['orders', 'list', userId],
    queryFn: async () => {
      if (!userId) throw { type: 'ORDER_NOT_FOUND', orderId: '' };
      const result = await getOrders.execute(userId);
      if (!result.success) throw result.error;
      return result.data;
    },
    enabled: Boolean(userId),
  });

  return {
    orders: query.data ?? [],
    isLoading: query.isLoading,
    error: query.error as OrderError | null,
    refetch: query.refetch,
  };
}
```

---

## Anti-Patterns

### ❌ Business logic in components instead of hooks

```typescript
// ❌ Bad — Component handles mutation and error logic directly
export function OrderDetailScreen({ orderId }: { orderId: string }) {
  const [isCancelling, setIsCancelling] = useState(false);

  const handleCancel = async () => {
    setIsCancelling(true);
    const result = await cancelOrderUseCase.execute(orderId);
    if (result.success) {
      router.back();
    } else {
      Alert.alert('Error', 'Could not cancel order');
    }
    setIsCancelling(false);
  };
}
```

Extract all mutation logic into `useCancelOrder`. The screen receives `cancelOrder` as a callback and `isCancelling` as state.

### ❌ Using `useEffect` + `useState` for server data

```typescript
// ❌ Bad — Manual fetch instead of TanStack Query
export function useUserProfile(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(true);
    getUserProfile.execute(userId).then((result) => {
      if (result.success) setUser(result.data);
      setIsLoading(false);
    });
  }, [userId]);

  return { user, isLoading };
}
```

This loses caching, background refetching, deduplication, stale-while-revalidate, and devtools integration. Use `useQuery`.

### ❌ Exposing raw `Result` from hooks to components

```typescript
// ❌ Bad — Component receives Result and must handle it
export function useUserProfile(userId: string) {
  const query = useQuery({ ... });
  return query.data; // Returns Result<User, UserError> — component must unwrap
}

// Component now has to know about Result:
const result = useUserProfile(userId);
if (!result.success) { ... }
```

Hooks unwrap `Result`. Components receive plain typed values or typed error objects.

---

[← Components](../features/components.md) | [Index](../../README.md) | [Index](../../README.md)
