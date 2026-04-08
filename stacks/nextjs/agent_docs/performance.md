---
description: Frontend performance — Server Components default, minimize useEffect, LCP/CLS/INP, dynamic imports
globs: "apps/client/src/**/*.tsx, apps/client/app/**/*.tsx"
alwaysApply: false
---

# Performance & Web Vitals — Frontend

## Principles
- Default to **Server Components**; keep client components as small leaf nodes.
- Minimize `useEffect` and client-side data fetching on first paint.
- Optimize for **LCP, CLS, INP** (Web Vitals).

## Client boundary rules
- Prefer server composition + pass serializable props.
- Split interactivity into small `'use client'` components.
- Wrap slow client islands with `Suspense` and a lightweight fallback.

## Loading strategy
- Use route-level `loading.tsx` for page skeletons when appropriate.
- Prefer **streaming + Suspense** over blocking spinners.

## Bundles
- Use dynamic imports for rare/optional UI:
  - `const Heavy = dynamic(() => import('./heavy'), { ssr: false })`
- Don’t import large libraries into shared root layouts.

## Images
- Use `next/image`.
- Provide `sizes` and correct `width/height`.
- Prefer modern formats (WebP/AVIF) and lazy-load non-critical images.

## Lists
- Avoid rendering huge lists at once; paginate/virtualize if needed.

## Measuring
- If a change is performance-motivated, state what metric should improve (LCP/CLS/INP) and how you would validate.
