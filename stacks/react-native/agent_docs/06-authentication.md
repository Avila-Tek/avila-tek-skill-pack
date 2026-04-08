# 06 · Authentication

Authentication in React Native is handled by **better-auth** with the `@better-auth/expo` plugin. better-auth is a framework-agnostic, TypeScript-first library that uses session-based authentication. The Expo plugin integrates with `expo-secure-store` for secure session caching and handles deep link callbacks for OAuth flows. There are no access/refresh tokens to manage, no manual `SecureStore` reads/writes, and no custom token rotation logic.

The auth client lives in the Infrastructure layer. Screens and hooks consume session state through `authClient.useSession()`. The Domain and Application layers never know about sessions, cookies, or HTTP headers — they receive a user ID and make business decisions based on it.

---

## Server Plugin

The server-side auth instance must include the `expo()` plugin to support mobile clients. This plugin configures the response format and deep link handling that the Expo client expects.

```typescript
// ✅ Good — server auth instance (NestJS or Next.js backend)
import { betterAuth } from 'better-auth';
import { expo } from '@better-auth/expo';

export const auth = betterAuth({
  // ...database, emailAndPassword, etc.
  plugins: [expo()],
  trustedOrigins: ['myapp://'],  // your app's deep link scheme
});
```

The `trustedOrigins` array must include your app's custom URL scheme. Without it, OAuth callbacks will fail.

---

## Auth Client Setup

Create the auth client with the `expoClient()` plugin. It uses `expo-secure-store` for persistent session caching — sessions survive app restarts without re-authentication.

```typescript
// ✅ Good — src/infrastructure/auth/auth-client.ts
import { createAuthClient } from 'better-auth/react';
import { expoClient } from '@better-auth/expo';
import * as SecureStore from 'expo-secure-store';

export const authClient = createAuthClient({
  baseURL: process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:3000',
  plugins: [
    expoClient({
      scheme: 'myapp',
      storagePrefix: 'myapp',
      storage: SecureStore,
    }),
  ],
});
```

```typescript
// ❌ Bad — manually managing tokens in SecureStore
import * as SecureStore from 'expo-secure-store';

async function login(email: string, password: string) {
  const response = await fetch('/api/auth/login', { body: JSON.stringify({ email, password }) });
  const { accessToken, refreshToken } = await response.json();
  await SecureStore.setItemAsync('accessToken', accessToken);
  await SecureStore.setItemAsync('refreshToken', refreshToken);
}
```

better-auth handles session persistence automatically through the `expoClient()` plugin. Never store tokens or sessions manually.

---

## Deep Link Configuration

OAuth flows (Google, Apple, GitHub) use deep links to redirect back to the app after authentication. Configure your app's URL scheme.

```json
// ✅ Good — app.json
{
  "expo": {
    "scheme": "myapp",
    "ios": {
      "bundleIdentifier": "com.avilatek.myapp"
    },
    "android": {
      "package": "com.avilatek.myapp"
    }
  }
}
```

The scheme must match what you pass to `expoClient({ scheme: 'myapp' })` and what the server lists in `trustedOrigins`.

---

## Sign In / Sign Up

Use `authClient.signIn.email()` and `authClient.signUp.email()` for email/password authentication.

```typescript
// ✅ Good — src/presentation/features/auth/hooks/use-sign-in.ts
import { useMutation } from '@tanstack/react-query';
import { useRouter } from 'expo-router';
import { authClient } from '@/infrastructure/auth/auth-client';

export function useSignIn() {
  const router = useRouter();

  return useMutation({
    mutationFn: async (credentials: { email: string; password: string }) => {
      const { error } = await authClient.signIn.email({
        email: credentials.email,
        password: credentials.password,
      });

      if (error) {
        throw new Error('Invalid credentials');
      }
    },
    onSuccess: () => {
      router.replace('/(app)/home');
    },
  });
}
```

```typescript
// ✅ Good — src/presentation/features/auth/hooks/use-sign-up.ts
import { useMutation } from '@tanstack/react-query';
import { authClient } from '@/infrastructure/auth/auth-client';

export function useSignUp() {
  return useMutation({
    mutationFn: async (data: { email: string; password: string; name: string }) => {
      const { error } = await authClient.signUp.email({
        email: data.email,
        password: data.password,
        name: data.name,
      });

      if (error) {
        throw new Error('Registration failed');
      }
    },
  });
}
```

---

## Session Hook

`authClient.useSession()` provides reactive session state. Use it to conditionally render UI based on authentication status.

```typescript
// ✅ Good — using session state in a component
import { authClient } from '@/infrastructure/auth/auth-client';

export function ProfileHeader() {
  const { data: session, isPending } = authClient.useSession();

  if (isPending) return <ActivityIndicator />;
  if (!session) return null;

  return (
    <View>
      <Text>{session.user.name}</Text>
      <Text>{session.user.email}</Text>
    </View>
  );
}
```

---

## Auth-Aware Navigation

Use `authClient.useSession()` in the root layout to control navigation between authenticated and unauthenticated stacks.

```typescript
// ✅ Good — src/app/_layout.tsx
import { Redirect, Stack } from 'expo-router';
import { authClient } from '@/infrastructure/auth/auth-client';

export default function RootLayout() {
  const { data: session, isPending } = authClient.useSession();

  if (isPending) return <SplashScreen />;

  if (!session) {
    return <Redirect href="/(auth)/sign-in" />;
  }

  return <Stack />;
}
```

```typescript
// ❌ Bad — checking auth in every screen
export default function HomeScreen() {
  const { data: session } = authClient.useSession();
  if (!session) return <Redirect href="/sign-in" />;
  // Duplicated in every screen
}
```

Handle authentication routing once at the layout level, not in every screen.

---

## Auth Store Integration

With better-auth, the manual Zustand auth store is no longer needed. The `authClient.useSession()` hook replaces in-memory auth state.

```typescript
// ❌ Bad — manual auth store (no longer needed)
export const useAuthStore = create<AuthState>((set) => ({
  userId: null,
  isAuthenticated: false,
  accessToken: null,
  setAuth: (userId, token) => set({ userId, isAuthenticated: true, accessToken: token }),
  logout: () => set({ userId: null, isAuthenticated: false, accessToken: null }),
}));

// ✅ Good — use authClient.useSession() instead
const { data: session } = authClient.useSession();
const isAuthenticated = !!session;
const userId = session?.user.id;
```

If you need to react to auth changes imperatively (e.g., clearing TanStack Query cache on sign-out), use `authClient.$Infer` types and the `onSessionChange` callback:

```typescript
// ✅ Good — clearing cache on sign-out
import { queryClient } from '@/lib/query-client';

export function useSignOut() {
  return useMutation({
    mutationFn: async () => {
      await authClient.signOut();
    },
    onSuccess: () => {
      queryClient.clear();
    },
  });
}
```

---

## Authenticated Requests

For API calls outside of better-auth's scope (e.g., custom business endpoints), the session cookie is automatically included in requests when using `fetch` with `credentials: 'include'`. For the `bearer()` plugin flow, use `authClient.getSession()` to retrieve the token.

```typescript
// ✅ Good — custom API calls include the session automatically
async function fetchOrders(): Promise<Order[]> {
  const response = await fetch(`${API_URL}/orders`, {
    credentials: 'include',
  });
  return response.json();
}
```

If your backend uses the `bearer()` plugin for mobile clients:

```typescript
// ✅ Good — using bearer token for API calls
const { data: session } = authClient.useSession();

async function fetchOrders(token: string): Promise<Order[]> {
  const response = await fetch(`${API_URL}/orders`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  return response.json();
}
```

---

## Social OAuth

Use `authClient.signIn.social()` for third-party authentication. The Expo plugin handles the web browser redirect and deep link callback.

```typescript
// ✅ Good — Google sign-in with OAuth
import { authClient } from '@/infrastructure/auth/auth-client';

export function useGoogleSignIn() {
  return useMutation({
    mutationFn: async () => {
      const { error } = await authClient.signIn.social({
        provider: 'google',
        callbackURL: '/(app)/home',
      });

      if (error) {
        throw new Error('Google sign-in failed');
      }
    },
  });
}
```

The `callbackURL` is the Expo Router path to navigate to after successful authentication. The `expoClient` plugin handles the deep link → app transition automatically.

---

## Anti-Patterns

### ❌ Storing tokens manually in SecureStore
```typescript
// ❌ Bad — manual token management
await SecureStore.setItemAsync('accessToken', token);
await SecureStore.setItemAsync('refreshToken', refreshToken);
// better-auth handles session persistence through expoClient()
```

### ❌ Not configuring `trustedOrigins` on the server
```typescript
// ❌ Bad — missing trusted origins for mobile scheme
export const auth = betterAuth({
  // trustedOrigins not set — OAuth callbacks from 'myapp://' will be rejected
});
```

### ❌ Using access/refresh token pattern instead of sessions
```typescript
// ❌ Bad — implementing JWT refresh logic
async function refreshToken() {
  const refresh = await SecureStore.getItemAsync('refreshToken');
  const response = await fetch('/auth/refresh', {
    body: JSON.stringify({ refreshToken: refresh }),
  });
  const { accessToken } = await response.json();
  await SecureStore.setItemAsync('accessToken', accessToken);
}
// better-auth sessions are server-managed — no client-side refresh needed
```

### ❌ Checking auth in every screen instead of the layout
```typescript
// ❌ Bad — duplicating auth checks
export default function SettingsScreen() {
  const { data: session } = authClient.useSession();
  if (!session) return <Redirect href="/sign-in" />;
  // Same check in HomeScreen, ProfileScreen, etc.
}
```
Handle auth routing at the `_layout.tsx` level. Individual screens can assume authentication.

---

[← State Management](./05-state-management.md) | [Index](./README.md) | [Next: Domain Layer →](./domain/domain.md)
