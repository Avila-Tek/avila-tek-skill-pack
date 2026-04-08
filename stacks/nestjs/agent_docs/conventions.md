---
description: Typed-array enum pattern with getEnumObjectFromArray — eliminating magic strings
globs: "**/*.ts, **/*.tsx"
alwaysApply: false
---

# Repo-wide conventions (examples)

## No magic strings — Typed-array enum pattern

Always use `getEnumObjectFromArray` from `@repo/utils` to define enums:

```ts
import { getEnumObjectFromArray } from '@repo/utils';

export const myEnum = ['value1', 'value2'] as const;
export type TMyEnum = (typeof myEnum)[number];
export const myEnumObject = getEnumObjectFromArray(myEnum);
```
