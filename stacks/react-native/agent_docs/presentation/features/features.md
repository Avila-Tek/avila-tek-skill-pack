# Features

A feature is a **vertical slice** of the presentation layer centered around a single domain concept. Rather than organizing the presentation layer by technical role (all screens in one folder, all components in another), Avila Tek organizes it by the domain concept each piece of code serves. All screens, components, and hooks for the "user profile" concept live together under `features/user/`.

This organizational choice reflects a fundamental truth about how applications evolve: features grow and change together. The screen, the components it renders, and the hooks that power them are modified as a unit when a feature changes. Keeping them co-located makes that work faster and reduces the chance of missing a related file.

---

## Feature as a Vertical Slice

```
src/presentation/features/
├── user/                          # Everything for the "user" domain concept
│   ├── screens/
│   │   ├── UserProfileScreen.tsx
│   │   └── EditUserProfileScreen.tsx
│   ├── components/
│   │   ├── UserAvatar.tsx
│   │   ├── UserProfileCard.tsx
│   │   └── UserStatusBadge.tsx
│   └── hooks/
│       ├── use-user-profile.ts
│       └── use-update-user-profile.ts
│
├── orders/                        # Everything for the "orders" domain concept
│   ├── screens/
│   │   ├── OrderListScreen.tsx
│   │   └── OrderDetailScreen.tsx
│   ├── components/
│   │   ├── OrderCard.tsx
│   │   ├── OrderItemRow.tsx
│   │   └── OrderStatusBadge.tsx
│   └── hooks/
│       ├── use-orders.ts
│       ├── use-order-detail.ts
│       └── use-cancel-order.ts
│
└── auth/                          # Everything for authentication
    ├── screens/
    │   ├── LoginScreen.tsx
    │   └── RegisterScreen.tsx
    ├── components/
    │   ├── LoginForm.tsx
    │   └── SocialLoginButton.tsx
    └── hooks/
        ├── use-login.ts
        └── use-register.ts
```

---

## Feature Boundaries

A feature boundary is the line between one domain concept and another. Code inside a feature is free to import from any file within that feature. Code must not import components or hooks from a different feature.

```typescript
// ✅ Good — Feature imports from within its own boundary
// src/presentation/features/orders/components/OrderCard.tsx

import { OrderStatusBadge } from './OrderStatusBadge';
import type { Order } from '@/domain/entities/order';
```

```typescript
// ❌ Bad — Cross-feature component import
// src/presentation/features/orders/components/OrderCard.tsx

import { UserAvatar } from '@/presentation/features/user/components/UserAvatar';
// UserAvatar should be in shared/components/ if it's needed by orders
```

---

## Shared Components

UI elements used across multiple features belong in `presentation/shared/`. Move a component to `shared/` as soon as a second feature needs it.

```
src/presentation/shared/
├── components/
│   ├── Button.tsx
│   ├── Input.tsx
│   ├── LoadingSpinner.tsx
│   ├── ErrorView.tsx
│   └── EmptyState.tsx
├── hooks/
│   ├── use-auth-guard.ts
│   └── use-toast.ts
└── stores/
    ├── ui-store.ts
    └── auth-store.ts
```

---

## What Belongs in a Feature

| File Type | Belongs in Feature? | Notes |
|---|---|---|
| Screen component | Yes | If tied to one domain concept |
| Feature-specific component | Yes | Only used within this feature |
| Feature-specific hook | Yes | Wraps use cases for this concept |
| Reused across 2+ features | No — move to `shared/` | |
| Zustand store | No — in `shared/stores/` | Stores are global by nature |
| Navigation helpers | In hooks only | As post-mutation side effects |

---

## Anti-Patterns

### ❌ Feature folder containing domain logic

```typescript
// ❌ Bad — Business logic inside a feature component
// src/presentation/features/orders/components/OrderCard.tsx

export function OrderCard({ order }: OrderCardProps) {
  // Business rule: discount calculation belongs in domain/use case
  const discountedTotal = order.total * (order.items.length > 5 ? 0.9 : 1);
  return <Text>{discountedTotal}</Text>;
}
```

### ❌ Monolithic feature folder with dozens of files

When a feature folder grows beyond ~15 files, consider whether it represents more than one bounded context. A `products/` feature that handles catalog browsing, cart management, and inventory tracking may need to be split into `catalog/`, `cart/`, and `inventory/` features.

---

[← Presentation Layer](../presentation.md) | [Index](../../README.md) | [Next: Screens →](./screens.md)
