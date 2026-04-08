# Components

Components are **pure and presentational**. They receive data through props, they render UI, and they call callbacks when the user interacts with them. They do not fetch data, they do not call hooks that trigger network requests, and they do not contain business logic. A component's sole job is to turn a data shape into pixels.

This constraint produces components that are trivially testable, composable, and reusable. A `UserProfileCard` that accepts a `User` prop renders identically whether it is in a screen, a story, or a test. It has no hidden dependencies on network state, global store, or navigation context.

---

## Pure / Presentational Components

```typescript
// ✅ Good — Pure presentational component
// src/presentation/features/user/components/UserProfileCard.tsx

import React from 'react';
import { View, Text, Image, Pressable } from 'react-native';
import type { User } from '@/domain/entities/user';

interface UserProfileCardProps {
  user: User;
  onEditPress?: () => void;
}

export function UserProfileCard({ user, onEditPress }: UserProfileCardProps) {
  return (
    <View className="bg-white rounded-2xl p-4 shadow-sm">
      {user.avatarUrl ? (
        <Image
          source={{ uri: user.avatarUrl }}
          className="w-16 h-16 rounded-full"
          accessibilityLabel={`${user.displayName}'s avatar`}
        />
      ) : (
        <View className="w-16 h-16 rounded-full bg-gray-200 items-center justify-center">
          <Text className="text-2xl font-bold text-gray-500">
            {user.displayName.charAt(0).toUpperCase()}
          </Text>
        </View>
      )}
      <Text className="text-xl font-bold text-gray-900 mt-3">{user.displayName}</Text>
      <Text className="text-sm text-gray-500">{user.email}</Text>
      {onEditPress && (
        <Pressable
          onPress={onEditPress}
          className="mt-4 bg-blue-600 rounded-lg py-2 px-4 items-center"
          accessibilityRole="button"
          accessibilityLabel="Edit profile"
        >
          <Text className="text-white font-semibold">Edit Profile</Text>
        </Pressable>
      )}
    </View>
  );
}
```

---

## NativeWind for Styling

Avila Tek uses **NativeWind** (Tailwind CSS for React Native) for all component styling. Inline `StyleSheet.create()` objects are not used for new components. NativeWind classes are applied via the `className` prop.

```typescript
// ✅ Good — NativeWind className for styling
export function OrderStatusBadge({ status }: OrderStatusBadgeProps) {
  const statusStyles: Record<OrderStatus, string> = {
    PENDING: 'bg-yellow-100 text-yellow-800',
    PROCESSING: 'bg-blue-100 text-blue-800',
    SHIPPED: 'bg-purple-100 text-purple-800',
    DELIVERED: 'bg-green-100 text-green-800',
    CANCELLED: 'bg-red-100 text-red-800',
    REFUNDED: 'bg-gray-100 text-gray-800',
  };

  const statusLabels: Record<OrderStatus, string> = {
    PENDING: 'Pending',
    PROCESSING: 'Processing',
    SHIPPED: 'Shipped',
    DELIVERED: 'Delivered',
    CANCELLED: 'Cancelled',
    REFUNDED: 'Refunded',
  };

  return (
    <View className={`rounded-full px-3 py-1 ${statusStyles[status]}`}>
      <Text className={`text-xs font-semibold ${statusStyles[status]}`}>
        {statusLabels[status]}
      </Text>
    </View>
  );
}
```

```typescript
// ❌ Bad — Inline StyleSheet in new components
import { StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  badge: { borderRadius: 999, paddingHorizontal: 12, paddingVertical: 4 },
  text: { fontSize: 12, fontWeight: '600' },
});
```

---

## Props Interface Naming

Every component has a named props interface following the `ComponentNameProps` pattern. The interface is defined in the same file as the component, above the component definition.

```typescript
// ✅ Good — Props interface co-located with component
interface OrderCardProps {
  order: Order;
  onPress: (orderId: string) => void;
  isHighlighted?: boolean;
}

export function OrderCard({ order, onPress, isHighlighted = false }: OrderCardProps) {
  return (
    <Pressable
      onPress={() => onPress(order.id)}
      className={`rounded-xl p-4 mb-3 ${isHighlighted ? 'border-2 border-blue-500' : 'border border-gray-200'}`}
    >
      <Text className="font-semibold text-gray-900">Order #{order.id.slice(0, 8)}</Text>
      <Text className="text-gray-500 text-sm">{order.items.length} items</Text>
      <OrderStatusBadge status={order.status} />
    </Pressable>
  );
}
```

---

## Avoiding Prop Drilling

When data needs to travel through more than two component levels, lift the data fetching to the screen or extract it into a shared hook. Do not pass props through intermediary components that do not use them.

```typescript
// ❌ Bad — Prop drilling through intermediary components
// Screen passes user to Section, Section passes to Detail, Detail passes to Avatar
<UserSection user={user}>
  <UserDetail user={user}>
    <UserAvatar user={user} />
  </UserDetail>
</UserSection>
```

```typescript
// ✅ Good — Deep component fetches its own data via hook (cached by TanStack Query)
// UserAvatar calls useUserProfile — TanStack Query deduplicates the request
export function UserAvatar({ userId }: { userId: string }) {
  const { user } = useUserProfile(userId);
  if (!user?.avatarUrl) return <DefaultAvatar />;
  return <Image source={{ uri: user.avatarUrl }} className="w-10 h-10 rounded-full" />;
}
```

Use the second approach when prop drilling through more than two levels. TanStack Query's cache ensures no duplicate requests are made.

---

## Accessibility

Every interactive component must include accessibility attributes:

```typescript
// ✅ Good — Accessibility on interactive components
<Pressable
  onPress={onEditPress}
  accessibilityRole="button"
  accessibilityLabel="Edit profile"
  accessibilityHint="Opens the profile editing screen"
>
  <Text>Edit</Text>
</Pressable>

<Image
  source={{ uri: user.avatarUrl }}
  accessibilityLabel={`${user.displayName}'s profile photo`}
/>
```

---

## Anti-Patterns

### ❌ Component fetching data internally with side effects

```typescript
// ❌ Bad — Component fetches its own data via network
export function UserProfileCard({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  useEffect(() => {
    fetch(`/users/${userId}`).then(r => r.json()).then(setUser);
  }, [userId]);
  return <Text>{user?.displayName}</Text>;
}
```

If a component needs server data, use `useQuery` via a custom hook — not `useEffect` + `fetch`.

### ❌ Components with business logic

```typescript
// ❌ Bad — Component applies business rules
export function OrderTotal({ order }: { order: Order }) {
  // Discount rule belongs in domain/use case
  const finalTotal = order.total > 100 ? order.total * 0.9 : order.total;
  return <Text>${finalTotal.toFixed(2)}</Text>;
}
```

### ❌ Using hardcoded colors or sizes instead of NativeWind tokens

```typescript
// ❌ Bad — Magic values outside of the design system
<View style={{ backgroundColor: '#3B82F6', borderRadius: 8, padding: 16 }}>
```

---

[← Screens](./screens.md) | [Index](../../README.md) | [Next: Hooks →](../hooks/hooks.md)
