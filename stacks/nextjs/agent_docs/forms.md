---
description: Form patterns — Zod schema + Form container + FormContent, react-hook-form + FormProvider
globs: "apps/client/src/features/**/domain/*.form.ts, apps/client/src/features/**/ui/widgets/*Form*.tsx"
alwaysApply: false
---

# Forms

## Three-piece pattern

Every form splits into three files:

| File | Layer | Responsibility |
|---|---|---|
| `*.form.ts` | Domain | Zod schema, inferred type, default values factory |
| `*Form.tsx` | UI / widgets | `useForm` + `zodResolver` + `FormProvider` + mutation |
| `*FormContent.tsx` | UI / widgets | Fields + error messages via `useFormContext` |

```
features/habits/
  domain/
    habits.form.ts
  ui/widgets/
    createHabitForm.tsx
    createHabitFormContent.tsx
```

Separating Form and FormContent allows reusing FormContent in modals, pages, or steppers without duplicating form logic.

---

## Domain: Schema (`*.form.ts`)

Three parts per schema: Zod definition, inferred type, default values factory.

```typescript
// features/habits/domain/habits.form.ts
import { z } from 'zod';

export const createHabitFormDefinition = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  description: z.string().max(500).optional(),
  frequency: z.enum(['daily', 'weekly']),
});

export type TCreateHabitForm = z.infer<typeof createHabitFormDefinition>;

export function createHabitDefaultValues(
  partial?: Partial<TCreateHabitForm>
): TCreateHabitForm {
  return {
    name: partial?.name ?? '',
    description: partial?.description ?? '',
    frequency: partial?.frequency ?? 'daily',
  };
}
```

Rules:
- Use `.safeParse()`, never `.parse()` (throws).
- Compose sub-schemas for reuse: `emailSchema`, `passwordSchema`.
- State-dependent validation (e.g., "name not taken") belongs in a use case, not the schema.

---

## UI: Form container (`*Form.tsx`)

```tsx
// features/habits/ui/widgets/createHabitForm.tsx
'use client';

import { useForm, FormProvider } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import {
  createHabitFormDefinition,
  createHabitDefaultValues,
  type TCreateHabitForm,
} from '../../domain/habits.form';
import { useCreateHabit } from '../../application/mutations/useCreateHabit.mutation';
import { CreateHabitFormContent } from './createHabitFormContent';

export function CreateHabitForm() {
  const mutation = useCreateHabit();

  const methods = useForm<TCreateHabitForm>({
    defaultValues: createHabitDefaultValues(),
    resolver: zodResolver(createHabitFormDefinition),
  });

  async function onSubmit(data: TCreateHabitForm) {
    if (mutation.isPending) return;
    await mutation.mutateAsync(data);
  }

  return (
    <FormProvider {...methods}>
      <form onSubmit={methods.handleSubmit(onSubmit)}>
        <CreateHabitFormContent
          disabled={mutation.isPending}
          error={mutation.error?.message}
        />
      </form>
    </FormProvider>
  );
}
```

Rules:
- Use `mutation.isPending` as the disabled state — no manual `useState` for loading.
- Form does not render fields — delegates to FormContent.
- For edit forms: `createHabitDefaultValues(existingHabit)`.

---

## UI: Form content (`*FormContent.tsx`)

```tsx
// features/habits/ui/widgets/createHabitFormContent.tsx
'use client';

import { useFormContext } from 'react-hook-form';
import { FormField, FormItem, FormLabel, FormControl, FormMessage } from '@repo/ui';
import { Input } from '@repo/ui';
import { Button } from '@repo/ui';
import type { TCreateHabitForm } from '../../domain/habits.form';

interface CreateHabitFormContentProps {
  disabled: boolean;
  error?: string;
}

export function CreateHabitFormContent({ disabled, error }: CreateHabitFormContentProps) {
  const { control } = useFormContext<TCreateHabitForm>();

  return (
    <div className="flex flex-col gap-4">
      <FormField
        control={control}
        name="name"
        render={({ field }) => (
          <FormItem>
            <FormLabel>Name</FormLabel>
            <FormControl>
              <Input {...field} disabled={disabled} />
            </FormControl>
            <FormMessage />
          </FormItem>
        )}
      />
      {error ? <p className="txt-error-primary text-sm">{error}</p> : null}
      <Button type="submit" disabled={disabled}>Create</Button>
    </div>
  );
}
```

---

## Dynamic validation (`superRefine`)

For cross-field validation — when one field's validity depends on another.

```typescript
// features/payOrder/domain/payOrder.form.ts
import { z } from 'zod';
import { getRoutingNumberRegex } from './transaction.logic';

const transactionDefinition = z.object({
  amount: z.number().positive(),
  isNational: z.boolean(),
  routingNumberType: z.enum(['aba', 'swift']).optional(),
  routingNumberCode: z.string().optional(),
});

export type TTransactionForm = z.infer<typeof transactionDefinition>;

function refineRoutingNumber(value: TTransactionForm, ctx: z.RefinementCtx) {
  if (value.isNational) return;

  if (!value.routingNumberCode) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Routing number is required for international transactions',
      path: ['routingNumberCode'],
    });
    return;
  }

  const regex = getRoutingNumberRegex(value.routingNumberType);
  if (regex && !regex.test(value.routingNumberCode)) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Invalid routing number format',
      path: ['routingNumberCode'],
    });
  }
}

export const payOrderFormDefinition = z.object({
  transactions: z
    .array(transactionDefinition.superRefine(refineRoutingNumber))
    .min(1, 'At least one transaction is required'),
});
```

---

## Anti-patterns

- **Forms without Zod** — Always validate with Zod for client/server consistency.
- **Monolithic form components** — Split into Form (logic) + FormContent (rendering).
- **Manual loading state** — Use `mutation.isPending`, not a separate `useState`.
- **Business logic in submit handlers** — Extract to domain logic or use cases.
- **Inline schema definitions** — Define schemas in `domain/*.form.ts`, not inside components.
- **`.parse()` instead of `.safeParse()`** — `.parse()` throws. Use `.safeParse()`.
