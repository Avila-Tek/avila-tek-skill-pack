# Screens

A screen is the top-level component for a route. It is the composition root of a feature: the place where hooks are called, data is fetched, and the result is handed down to presentational components. Screens do not contain layout code or style details — they orchestrate. Components render.

The separation of Screen from View (or Screen from its constituent components) is the most important structural decision in the presentation layer. A screen that fetches data and renders it inline is a screen that cannot be unit-tested without network mocking. A screen that delegates rendering to pure components is a screen where each piece is testable in isolation.

---

## Screen as Composition Root

The screen's responsibilities are:
1. Call hooks to obtain data and actions
2. Handle loading and error states
3. Pass data to child components as props
4. Wire event handlers from components to hook actions

```typescript
// ✅ Good — Screen as pure composition root
// src/presentation/features/user/screens/UserProfileScreen.tsx

import React from 'react';
import { View, ScrollView } from 'react-native';
import { useUserProfile } from '../hooks/use-user-profile';
import { UserProfileCard } from '../components/UserProfileCard';
import { LoadingSpinner } from '@/presentation/shared/components/LoadingSpinner';
import { ErrorView } from '@/presentation/shared/components/ErrorView';

interface UserProfileScreenProps {
  userId: string;
}

export function UserProfileScreen({ userId }: UserProfileScreenProps) {
  const { user, error, isLoading } = useUserProfile(userId);

  if (isLoading) {
    return <LoadingSpinner />;
  }

  if (error) {
    return <ErrorView error={error} />;
  }

  if (!user) {
    return null;
  }

  return (
    <ScrollView>
      <UserProfileCard user={user} />
    </ScrollView>
  );
}
```

---

## Expo Router File Conventions

Expo Router uses file-system routing. Files in `src/app/` define routes. These route files are thin wrappers that import screen components from `presentation/features/`.

```
src/app/
├── (auth)/
│   ├── login.tsx              → renders LoginScreen
│   └── register.tsx           → renders RegisterScreen
└── (main)/
    ├── index.tsx              → renders HomeScreen
    └── profile/
        └── [id].tsx           → renders UserProfileScreen with id param
```

```typescript
// ✅ Good — Expo Router route file (thin wrapper)
// src/app/(main)/profile/[id].tsx

import { useLocalSearchParams } from 'expo-router';
import { UserProfileScreen } from '@/presentation/features/user/screens/UserProfileScreen';

export default function UserProfileRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <UserProfileScreen userId={id} />;
}
```

```typescript
// ✅ Good — Route file with Stack header configuration
// src/app/(main)/orders/[id].tsx

import { Stack, useLocalSearchParams } from 'expo-router';
import { OrderDetailScreen } from '@/presentation/features/orders/screens/OrderDetailScreen';

export default function OrderDetailRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return (
    <>
      <Stack.Screen options={{ title: 'Order Details' }} />
      <OrderDetailScreen orderId={id} />
    </>
  );
}
```

---

## Screen vs View Separation

For complex screens, separate the data-fetching screen from a pure view component:

```typescript
// ✅ Good — Pure view component receives already-fetched data
// src/presentation/features/user/screens/UserProfileView.tsx

import { View, Text, Image } from 'react-native';
import type { User } from '@/domain/entities/user';

interface UserProfileViewProps {
  user: User;
  onEditPress: () => void;
}

export function UserProfileView({ user, onEditPress }: UserProfileViewProps) {
  return (
    <View>
      {user.avatarUrl && <Image source={{ uri: user.avatarUrl }} />}
      <Text>{user.displayName}</Text>
      <Text>{user.email}</Text>
    </View>
  );
}

// ✅ Good — Screen fetches, passes to view
// src/presentation/features/user/screens/UserProfileScreen.tsx

export function UserProfileScreen({ userId }: { userId: string }) {
  const { user, isLoading, error } = useUserProfile(userId);
  const { navigate } = useRouter();

  if (isLoading) return <LoadingSpinner />;
  if (error || !user) return <ErrorView />;

  return (
    <UserProfileView
      user={user}
      onEditPress={() => navigate('/profile/edit')}
    />
  );
}
```

---

## Naming

| Item | Convention | Example |
|---|---|---|
| Screen component | `PascalCase` + `Screen` suffix | `UserProfileScreen` |
| Route file | kebab-case or `[param].tsx` | `user-profile.tsx`, `[id].tsx` |
| Screen file | `PascalCaseScreen.tsx` | `UserProfileScreen.tsx` |

---

## Anti-Patterns

### ❌ Screen containing inline data fetching

```typescript
// ❌ Bad — Screen does its own data fetching
export function UserProfileScreen({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => {
    userApi.getUser(userId).then(setUser); // Direct API call in screen
  }, [userId]);
  return <Text>{user?.displayName}</Text>;
}
```

### ❌ Business logic in a screen

```typescript
// ❌ Bad — Screen contains business rule
export function CheckoutScreen() {
  const { cart } = useCart();
  const total = cart.items.reduce((sum, item) => {
    // Business rule: tax calculation belongs in a use case or domain
    const tax = item.price * 0.16;
    return sum + item.price + tax;
  }, 0);
}
```

---

[← Features](./features.md) | [Index](../../README.md) | [Next: Components →](./components.md)
