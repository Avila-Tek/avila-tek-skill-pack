# 05 · State Management

State management is one of the most mishandled concerns in React Native development. Engineers reach for a single state solution and force every kind of state into it — server data, loading flags, modal visibility, form values, and user preferences all end up in the same store, creating unnecessary complexity and coupling. Avila Tek's approach is deliberate segmentation: each kind of state is handled by the tool purpose-built for it.

The rule is simple. Server state — data that originates from a remote source and must be synchronized — belongs in **TanStack Query**. Local UI state — what is visible, what is selected, transient interaction state — belongs in **Zustand**. Ephemeral component state — input focus, animation progress — belongs in **`useState`**. This separation is not optional. Mixing these categories produces caches that go stale at the wrong times, stores that grow without bound, and components that re-render unnecessarily.

---

## The Two-Store Philosophy

```
┌─────────────────────────────────────────────────────────────┐
│                    STATE CATEGORIES                          │
│                                                             │
│  ┌──────────────────────┐   ┌───────────────────────────┐  │
│  │   SERVER STATE        │   │     LOCAL UI STATE        │  │
│  │   TanStack Query      │   │       Zustand             │  │
│  │                       │   │                           │  │
│  │  • API response data  │   │  • Modal open/closed      │  │
│  │  • User profile       │   │  • Active tab index       │  │
│  │  • Order list         │   │  • Selected filter        │  │
│  │  • Pagination         │   │  • Toast notifications    │  │
│  │  • Cache + refetch    │   │                           │  │
│  └──────────────────────┘   └───────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               COMPONENT STATE                        │   │
│  │                  useState                            │   │
│  │                                                     │   │
│  │  • Input value while typing                         │   │
│  │  • Dropdown expanded/collapsed                      │   │
│  │  • Hover/pressed state                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Decision Matrix

Use this matrix when deciding where to put state:

| Question | Answer → Use |
|---|---|
| Does this data come from an API? | TanStack Query |
| Does this data need background refetching? | TanStack Query |
| Is this data shared across multiple screens? | TanStack Query (if server) or Zustand (if UI) |
| Is this a loading/error state from a fetch? | TanStack Query (built-in) |
| Is this UI-only and never persisted to a server? | Zustand |
| Does only one component ever need this? | `useState` |
| Is this ephemeral (gone when component unmounts)? | `useState` |
| Is this a user preference stored locally? | Zustand + AsyncStorage |

---

## TanStack Query Setup

The `QueryClient` is configured once at the application root. It is instantiated outside of React to prevent recreation on re-renders.

```typescript
// ✅ Good — QueryClient configuration
// src/lib/query-client.ts

import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,     // 5 minutes — data stays fresh
      gcTime: 1000 * 60 * 10,       // 10 minutes — cache retention
      retry: 2,                      // Retry failed requests twice
      refetchOnWindowFocus: false,   // Disable — mobile app behavior
    },
    mutations: {
      retry: 0,                      // Never retry mutations
    },
  },
});
```

```typescript
// ✅ Good — Provider in root layout
// src/app/_layout.tsx

import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from '@/lib/query-client';

export default function RootLayout() {
  return (
    <QueryClientProvider client={queryClient}>
      <UseCaseProvider>
        <Stack />
      </UseCaseProvider>
    </QueryClientProvider>
  );
}
```

### Query Keys

Query keys are arrays that uniquely identify a cache entry. They should be structured from general to specific:

```typescript
// ✅ Good — Hierarchical query keys
const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  detail: (id: string) => [...userKeys.all, 'detail', id] as const,
};

// Usage:
useQuery({ queryKey: userKeys.detail(userId), queryFn: ... });
// Invalidate all user queries:
queryClient.invalidateQueries({ queryKey: userKeys.all });
// Invalidate one user:
queryClient.invalidateQueries({ queryKey: userKeys.detail(userId) });
```

```typescript
// ❌ Bad — Unstructured query keys
useQuery({ queryKey: ['getUser', userId], queryFn: ... });  // Inconsistent
useQuery({ queryKey: [userId], queryFn: ... });             // Too minimal
useQuery({ queryKey: ['users'], queryFn: () => fetch(`/users/${userId}`) }); // Key doesn't include userId
```

---

## Zustand Store Design

Zustand stores should be **small and focused**. Each store owns one concern. Split stores by domain, not by size.

```typescript
// ✅ Good — Focused Zustand store for UI state
// src/presentation/shared/stores/ui-store.ts

import { create } from 'zustand';

interface Toast {
  id: string;
  message: string;
  type: 'success' | 'error' | 'info';
}

interface UiState {
  toasts: Toast[];
  addToast: (toast: Omit<Toast, 'id'>) => void;
  removeToast: (id: string) => void;
  isGlobalLoading: boolean;
  setGlobalLoading: (loading: boolean) => void;
}

export const useUiStore = create<UiState>((set) => ({
  toasts: [],
  addToast: (toast) =>
    set((state) => ({
      toasts: [...state.toasts, { ...toast, id: crypto.randomUUID() }],
    })),
  removeToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((t) => t.id !== id),
    })),
  isGlobalLoading: false,
  setGlobalLoading: (loading) => set({ isGlobalLoading: loading }),
}));
```

```typescript
// ✅ Good — Auth state via better-auth (no manual store needed)
// Use authClient.useSession() instead of a manual Zustand auth store.
// See guide 06-authentication.md for full setup.

import { authClient } from '@/infrastructure/auth/auth-client';

function ProfileScreen() {
  const { data: session, isPending } = authClient.useSession();
  const isAuthenticated = !!session;
  const userId = session?.user.id ?? null;
  // ...
}
```

```typescript
// ❌ Bad — Monolithic Zustand store that mixes concerns
// src/stores/app-store.ts

export const useAppStore = create((set) => ({
  // Server data — belongs in TanStack Query
  users: [],
  orders: [],
  currentUser: null,
  fetchUsers: async () => { ... },
  fetchOrders: async () => { ... },

  // UI state — OK in Zustand
  isModalOpen: false,
  activeTab: 0,

  // Everything mixed together with no clear ownership
}));
```

---

## Unidirectional Data Flow

```
  User Interaction
       │
       ▼
  Zustand action / TanStack Query mutation trigger
       │
       ├── Zustand: synchronous state update
       │        └─► UI re-renders with new local state
       │
       └── TanStack Query mutation:
                └─► Use case executes
                └─► API call made
                └─► Cache invalidated/updated
                └─► UI re-renders with fresh server data
```

Data flows in one direction. Components never write directly to the cache or the server. All writes go through Zustand actions (for UI state) or TanStack Query mutations (for server state), both of which are invoked from hooks.

---

## Combining TanStack Query and Zustand

They complement each other. A common pattern is a mutation that, on success, also updates Zustand state:

```typescript
// ✅ Good — Mutation updates server cache and local state together
// src/presentation/features/user/hooks/use-login.ts

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useAuthStore } from '@/presentation/shared/stores/auth-store';
import { useUseCaseContext } from '@/presentation/context/use-case-context';

export function useLogin() {
  const { login } = useUseCaseContext();
  const queryClient = useQueryClient();
  const setUserId = useAuthStore((s) => s.setUserId);

  return useMutation({
    mutationFn: (credentials: { email: string; password: string }) =>
      login.execute(credentials),
    onSuccess: (result) => {
      if (!result.success) return;
      setUserId(result.data.userId);
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
  });
}
```

---

## Anti-Patterns

### ❌ `useState` for server data

```typescript
// ❌ Bad — Manual data fetching with useState
function UserList() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    setLoading(true);
    fetch('/users').then(r => r.json()).then(data => {
      setUsers(data);
      setLoading(false);
    });
  }, []);
}
```

This loses caching, deduplication, background refetching, error states, and retry logic that TanStack Query provides for free.

### ❌ Zustand for server/async data

```typescript
// ❌ Bad — Zustand managing async server data
export const useUserStore = create((set) => ({
  user: null,
  isLoading: false,
  error: null,
  fetchUser: async (id: string) => {
    set({ isLoading: true });
    try {
      const data = await api.getUser(id);
      set({ user: data, isLoading: false });
    } catch (e) {
      set({ error: e, isLoading: false });
    }
  },
}));
```

Zustand is a synchronous state container. Putting async fetch logic here bypasses all of TanStack Query's cache management, deduplication, and stale-while-revalidate behavior.

### ❌ Prop-drilling query results through many levels

```typescript
// ❌ Bad — Passing server data as props through 4 layers
<Screen>
  <View user={user}>
    <Section user={user}>
      <Detail user={user} />
    </Section>
  </View>
</Screen>
```

Call `useUserProfile` directly in the component that needs it. TanStack Query deduplicates the request if the query key matches.

---

[← Error Handling](./04-error-handling.md) | [Index](./README.md) | [Next: Authentication →](./06-authentication.md)
