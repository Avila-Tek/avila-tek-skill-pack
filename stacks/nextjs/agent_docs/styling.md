---
description: Design token conventions — semantic CSS utilities for colors, backgrounds, borders
globs: "apps/client/src/**/*.tsx, apps/admin/src/**/*.tsx, packages/ui/src/**/*.tsx"
alwaysApply: false
---
# Design Tokens & Styling — Frontend

## Rule: never use primitive color classes

Tailwind primitives like `bg-brand-600`, `text-gray-light-mode-700`, `border-error-500` **must not** be used directly in components. Instead, use the **semantic utility tokens** defined in `src/css/`:

| File | Purpose | Examples |
|---|---|---|
| `bg-variables.css` | Backgrounds | `bg-brand-solid`, `bg-surface`, `bg-error-solid` |
| `text-variables.css` | Text colors | `txt-primary-900`, `txt-secondary-700`, `txt-brand-secondary-700` |
| `border-variables.css` | Borders | `border-primary`, `border-brand`, `border-error` |
| `fg-variables.css` | Foreground / icon colors | `fg-brand-primary`, `fg-secondary` |
| `color-variables.css` | Primitive palette definition | **Reference only — don't use in components** |

### Why

Semantic tokens resolve light/dark mode automatically via `@apply` + `dark:` variants. Using primitives breaks dark mode and diverges from the Figma design system.

### Quick example

```tsx
// Bad
<div className="bg-brand-600 text-white border-brand-500" />

// Good
<div className="bg-brand-solid txt-primary_on-brand border-brand" />
```
