---
description: Feature flags with PostHog — typed flags, useFeatureFlagValue, packages/feature-flags
globs: "packages/feature-flags/src/**/*.ts, packages/feature-flags/src/**/*.tsx"
alwaysApply: false
---

# Feature Flags

## Architecture

Feature flags live in `packages/feature-flags/` — a shared package used by both client and admin apps.

The package uses a **provider pattern** that supports multiple backends (PostHog, GrowthBook). The active provider is configured per-app.

```
packages/feature-flags/src/
  shared/
    resources.ts        # Flag definitions + provider enum (typed-array pattern)
  web/
    context/
      FeatureFlagContext.tsx              # React context + provider component
      providers/
        PostHogCustomProvider.tsx         # PostHog implementation
    hooks/
      useFeatureFlags.ts                 # Consumer hooks
```

---

## Setup in apps

The `FeatureFlagContextProvider` is imported with `dynamic()` + `ssr: false` to avoid hydration mismatches and keep the PostHog SDK out of the server bundle:

```tsx
// src/context/client-providers.tsx
import dynamic from 'next/dynamic';

const FeatureFlagContextProvider = dynamic(
  () => import('@repo/feature-flags').then((m) => m.FeatureFlagContextProvider),
  { ssr: false }
);

export function ClientProviders({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <FeatureFlagContextProvider
        provider="post_hog"
        postHogToken={process.env.NEXT_PUBLIC_POSTHOG_KEY!}
        postHogHost={process.env.NEXT_PUBLIC_POSTHOG_HOST!}
      >
        {children}
      </FeatureFlagContextProvider>
    </QueryClientProvider>
  );
}
```

**Required env vars:** `NEXT_PUBLIC_POSTHOG_KEY`, `NEXT_PUBLIC_POSTHOG_HOST`, `NEXT_PUBLIC_FEATURE_FLAG_ENV` (defaults to `'prod'`).

---

## Defining flags

Flags are defined in `packages/feature-flags/src/shared/resources.ts` using the typed-array enum pattern:

```typescript
import { getEnumObjectFromArray } from '@repo/utils';

export const availableFeatureFlags = ['release_full_template'] as const;
export type TFeatureFlagEnum = (typeof availableFeatureFlags)[number];
export const featureFlags = getEnumObjectFromArray(availableFeatureFlags);
```

When adding a new flag:
1. Add to the `availableFeatureFlags` array
2. Create the flag in PostHog dashboard
3. Use the typed constant in code (`featureFlags.release_full_template`)

---

## Hooks API

All hooks must be used inside `FeatureFlagContextProvider`:

```typescript
import { useFeatureFlagValue, useFeatureFlagPayload, useIdentifyUser } from '@repo/feature-flags';

// Boolean flag check
const isEnabled = useFeatureFlagValue('release_full_template'); // boolean

// Flag with payload (for A/B tests, rollout configs)
const payload = useFeatureFlagPayload('release_full_template'); // unknown

// Identify user for targeted flags
const identifyUser = useIdentifyUser();
identifyUser({ id: user.id }); // Call after login
```

### Centralize flag checks in custom hooks

Don't scatter flag checks across components. Wrap in a feature-specific hook:

```typescript
// features/billing/hooks/useBillingFeatures.ts
export function useBillingExportV2() {
  return useFeatureFlagValue('prod-billing-export-v2-release');
}
```

---

## Naming convention

Flag names follow the pattern: `{env}-{module}-{feature}-{version}-{type}`

| Segment | Values | Example |
|---|---|---|
| env | `prod`, `stg`, `dev` | `prod` |
| module | Feature area | `billing`, `auth`, `onboarding` |
| feature | Specific capability | `export`, `sign-up-by-role` |
| version | Iteration | `v1`, `v2` |
| type | `release`, `experiment`, `ops` | `release` |

Examples:
- `prod-billing-export-v2-release`
- `stg-auth-sign-up-by-role-v1-experiment`

---

## Anti-patterns

- **Stale/orphan flags** — Remove flags after rollout is complete. Dead flags accumulate and confuse.
- **No fallback behavior** — Always handle the "flag off" case. If PostHog is down, the app should still work with sensible defaults.
- **Checking flags in multiple places** — Centralize in a custom hook. One flag, one hook, one source of truth.
- **Flags for permanent configuration** — Feature flags are temporary. If it will never be removed, use an environment variable or config file instead.
- **Flag checks in Server Components** — The current PostHog integration is client-side only. Don't use flag hooks in Server Components.
