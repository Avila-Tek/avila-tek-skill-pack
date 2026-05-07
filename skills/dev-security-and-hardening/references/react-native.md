# React Native — Security Reference (OWASP Mobile Top 10)

## M1 · Improper Credential Usage

Never store auth tokens or sensitive data in `AsyncStorage` — it is unencrypted plaintext. Use `expo-secure-store` (iOS Keychain / Android Keystore):

```typescript
// ✅ better-auth with expoClient — secure storage handled automatically
import { createAuthClient } from 'better-auth/react';
import { expoClient } from '@better-auth/expo';
import * as SecureStore from 'expo-secure-store';

export const authClient = createAuthClient({
  baseURL: process.env.EXPO_PUBLIC_API_URL,
  plugins: [expoClient({ scheme: 'myapp', storagePrefix: 'myapp', storage: SecureStore })],
});

// ❌ Never manage tokens manually
await SecureStore.setItemAsync('accessToken', token); // better-auth handles this
await AsyncStorage.setItem('token', token);           // unencrypted — never for tokens
```

Never store credentials in `MMKV` or `AsyncStorage`, even if they seem "temporary".

## M2 · Inadequate Supply Chain Security

Pin dependencies in `package.json` with exact versions for security-critical packages. Run audits regularly:

```bash
npm audit              # check for known vulnerabilities
npm audit --fix        # auto-fix where safe
```

Audit new packages before adding — prefer widely-used, actively maintained libraries.

## M3 · Insecure Authentication/Authorization

Auth routing belongs in `_layout.tsx` — handle it once, not in every screen:

```typescript
// ✅ src/app/_layout.tsx — one auth gate for the entire app
export default function RootLayout() {
  const { data: session, isPending } = authClient.useSession();

  if (isPending) return <SplashScreen />;
  if (!session) return <Redirect href="/(auth)/sign-in" />;

  return <Stack />;
}

// ❌ Never duplicate auth checks in individual screens
export default function HomeScreen() {
  const { data: session } = authClient.useSession();
  if (!session) return <Redirect href="/sign-in" />; // duplicated in every screen
}
```

`authClient.useSession()` replaces manual Zustand auth store — no DIY auth state management:

```typescript
// ✅ better-auth manages session state reactively
const { data: session } = authClient.useSession();
const isAuthenticated = !!session;

// ❌ Manual auth store (prone to out-of-sync state)
const { isAuthenticated } = useAuthStore();
```

On sign-out, clear all cached data:

```typescript
export function useSignOut() {
  return useMutation({
    mutationFn: () => authClient.signOut(),
    onSuccess: () => queryClient.clear(), // clear all cached server state
  });
}
```

## M4 · Insufficient Input/Output Validation

Validate all form inputs with Zod before sending to the API. Validate all API responses before use in domain logic:

```typescript
// ✅ Input validation with Zod
const SignInSchema = z.object({
  email: z.string().email('Invalid email').trim().toLowerCase(),
  password: z.string().min(8, 'Minimum 8 characters'),
});

// ✅ API response validation
const OrderSchema = z.object({ id: z.string(), total: z.number() });
const response = await fetch(`${API_URL}/orders`);
const raw = await response.json();
const parsed = OrderSchema.array().safeParse(raw);
if (!parsed.success) throw new Error('Unexpected API response shape');
```

## M5 · Insecure Communication

Enforce HTTPS for all API calls. Never disable TLS certificate verification:

```typescript
// ✅ All API calls over HTTPS
const API_URL = process.env.EXPO_PUBLIC_API_URL; // must be https://

// ❌ Never disable cert verification — even in development
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'; // never
```

For authenticated requests, credentials are included automatically by better-auth session cookies. For bearer-based flows:

```typescript
// ✅ Retrieve session token securely via better-auth
const { data: session } = authClient.useSession();
const response = await fetch(`${API_URL}/orders`, {
  headers: { Authorization: `Bearer ${session?.token}` },
});
```

Deep links for OAuth must validate the scheme matches `trustedOrigins` on the server:

```typescript
// ✅ app.json — scheme must match server trustedOrigins
{
  "expo": {
    "scheme": "myapp",       // must match betterAuth({ trustedOrigins: ['myapp://'] })
    "ios": { "bundleIdentifier": "com.avilatek.myapp" },
    "android": { "package": "com.avilatek.myapp" }
  }
}
```

## M6 · Inadequate Privacy Controls

Never log tokens, passwords, session cookies, or PII:

```typescript
// ✅
console.log('User signed in', { userId: session.user.id });

// ❌
console.log('Session:', JSON.stringify(session));  // may contain tokens
console.log('Password:', password);                // never
console.log('Request body:', JSON.stringify(body)); // may contain credentials
```

Request bodies that contain credentials should never be logged in interceptors.

## M7 · Insufficient Binary Protections

Enable Hermes and minification for release builds. Disable source maps in production:

```json
// app.json — disable source maps in production
{
  "expo": {
    "updates": { "enabled": true },
    "ios": { "jsEngine": "hermes" },
    "android": { "jsEngine": "hermes" }
  }
}
```

Never include API keys, secrets, or admin credentials in the app bundle. Use `EXPO_PUBLIC_` only for non-sensitive values. All sensitive config must go server-side.

## M8 · Security Misconfiguration

Remove `__DEV__` blocks from release builds or gate them explicitly:

```typescript
// ✅ Development-only code clearly gated
if (__DEV__) {
  // mock data, verbose logging, etc.
}
```

Disable Flipper and React Native Debugger in production — they expose the JS bundle and state.

## M9 · Insecure Data Storage

| Data Type | Storage |
|---|---|
| Auth session | `expo-secure-store` via better-auth expoClient |
| API keys, secrets | Never in the client — server-side only |
| Non-sensitive user preferences | `AsyncStorage` or `MMKV` |
| Sensitive documents | Encrypted with `expo-crypto` + `expo-file-system` |

## M10 · Insufficient Cryptography

Use platform-provided crypto via `expo-crypto`. Never implement custom cryptographic algorithms:

```typescript
// ✅ Use expo-crypto for hashing and random values
import * as Crypto from 'expo-crypto';

const hash = await Crypto.digestStringAsync(
  Crypto.CryptoDigestAlgorithm.SHA256,
  data
);
const randomBytes = await Crypto.getRandomBytesAsync(32);

// ❌ Never implement custom hash functions
```

## Verification Checklist

- [ ] Auth tokens in `expo-secure-store` via better-auth `expoClient()` — never `AsyncStorage`
- [ ] Auth routing in root `_layout.tsx` — not duplicated across screens
- [ ] No manual Zustand auth store — use `authClient.useSession()`
- [ ] Sign-out calls `queryClient.clear()` to purge cached data
- [ ] All form inputs validated with Zod before API calls
- [ ] All API responses validated with Zod before domain use
- [ ] All API calls over HTTPS — `EXPO_PUBLIC_API_URL` starts with `https://`
- [ ] Deep link `scheme` matches server `trustedOrigins`
- [ ] No tokens, passwords, or PII in logs
- [ ] No secrets in app bundle — only `EXPO_PUBLIC_` for non-sensitive config
- [ ] Hermes enabled for release builds
- [ ] `npm audit` clean in CI
