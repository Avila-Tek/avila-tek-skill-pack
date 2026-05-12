# Next.js — Reference Components

Minimal reference implementations for all shared UI components the stack patterns depend on. Use these when a project scan finds a component missing. **Adapt styling to the project's design system — the contracts (props, behavior) must be preserved.**

Organized by category:
- [Shared](#shared) — used across features
- [Layout & Navigation](#layout--navigation) — page shells, permission gates, routing
- [Form Components](#form-components) — for `manage<Entity>` features
- [Table Components](#table-components) — for `view<Entity>` features

For E2E testing infrastructure (MockHttpClient, Cypress commands), see `references/testing-utilities.md`.

---

## Shared

### PrefetchBoundary

Server component that abstracts `HydrationBoundary + dehydrate + getQueryClient`. Accepts an array of `queryOptions` results and prefetches all of them before hydrating children.

**Key contract:** `queries` accepts `QueryObserverOptions[]` — pass `queryOptions()` return values, not fetch functions. Children receive pre-hydrated data on the client without extra wiring.

```tsx
import { HydrationBoundary, dehydrate, type QueryObserverOptions } from '@tanstack/react-query';
import { getQueryClient } from '@/lib/getQueryClient';
import * as React from 'react';

interface PrefetchBoundaryProps {
  queries: QueryObserverOptions[];
  children: React.ReactNode;
}

export default async function PrefetchBoundary({ queries, children }: PrefetchBoundaryProps): Promise<React.ReactElement> {
  const queryClient = getQueryClient();
  await Promise.all(queries.map((q) => queryClient.prefetchQuery(q)));
  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      {children}
    </HydrationBoundary>
  );
}

export type { PrefetchBoundaryProps };
```

---

### QueryResultGuard

Declarative wrapper for `useSuspenseQuery` loaders. Inspects a `Safe<T>` result and renders either the children (render prop, receives unwrapped data) or an `ErrorState` inline.

**Key contract:** Uses a render prop — `children` receives the unwrapped `T` directly. `result.success === false` renders `ErrorState` without any `useEffect`, `useRouter`, or redirect side effects. Always preserves the page layout context.

```tsx
import * as React from 'react';
import ErrorState from './ErrorState';

type Safe<T> = { success: true; data: T; message?: string } | { success: false; error: string };

interface QueryResultGuardProps<T> {
  result: Safe<T>;
  children: (data: T) => React.ReactNode;
  redirectTo: string;
  title?: string;
  description?: string;
}

export default function QueryResultGuard<T>({
  result,
  children,
  redirectTo,
  title,
  description,
}: QueryResultGuardProps<T>): React.ReactElement {
  if (!result.success) {
    return (
      <ErrorState
        title={title}
        description={description ?? result.error}
        redirectTo={redirectTo}
      />
    );
  }
  return <>{children(result.data)}</>;
}

export type { QueryResultGuardProps, Safe };
```

---

### ErrorState

Presentational component for inline error states. Used by `QueryResultGuard` and can be used independently.

**Key contract:** `redirectTo` is required — always provide a navigation escape hatch. No side effects — purely presentational.

```tsx
import * as React from 'react';
import Link from 'next/link';

interface ErrorStateProps {
  redirectTo: string;
  title?: string;
  description?: string;
  redirectLabel?: string;
  icon?: React.ReactNode;
}

export default function ErrorState({
  redirectTo,
  title,
  description,
  redirectLabel = 'Volver',
  icon,
}: ErrorStateProps): React.ReactElement {
  return (
    <div className="flex flex-col items-center justify-center gap-4 p-8 text-center">
      {icon ? <div>{icon}</div> : null}
      {title ? <h2 className="text-lg font-semibold">{title}</h2> : null}
      {description ? <p className="text-sm text-gray-500">{description}</p> : null}
      <Link href={redirectTo} className="text-sm text-blue-600 underline">
        {redirectLabel}
      </Link>
    </div>
  );
}

export type { ErrorStateProps };
```

---

## Layout & Navigation

### PermissionGuard

Renders children only if the current user has all required permissions. Used to gate UI elements (buttons, sections) — not routes (use middleware or page-level guards for that).

**Key contract:** `permissions` is a string array — all must be present for children to render. Use `fallback` to show an alternative element when access is denied (defaults to nothing). Wire `hasPermissions` to the project's auth context.

```tsx
'use client';
import * as React from 'react';

interface PermissionGuardProps {
  permissions: string[];
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export default function PermissionGuard({
  permissions,
  children,
  fallback = null,
}: PermissionGuardProps): React.ReactElement {
  // Replace with the project's permission hook (e.g. useSession, useUser, useAuth)
  const { hasPermissions } = usePermissions();
  if (!hasPermissions(permissions)) return <>{fallback}</>;
  return <>{children}</>;
}

export type { PermissionGuardProps };
```

> If the project has no `usePermissions` hook, locate the session/user hook (e.g. `useSession`, `useAuth`) and derive the check from `user.roles` or `user.permissions`. Show the developer what you found and align before implementing.

---

### AdminPageLayout

Page shell for admin features. Provides title, optional breadcrumbs, optional header action slot, and a permission gate.

**Key contract:** `permissions` — if provided, the layout checks them before rendering children (use `PermissionGuard` internally). `headerAction` is for page-level CTAs (e.g. a "Create" button). Adapt the HTML/styling to the project's design system.

```tsx
import * as React from 'react';
import PermissionGuard from './PermissionGuard';

interface BreadcrumbItem {
  label: string;
  href?: string;
}

interface AdminPageLayoutProps {
  title: string;
  children: React.ReactNode;
  permissions?: string[];
  breadcrumbs?: BreadcrumbItem[];
  headerAction?: React.ReactNode;
}

export default function AdminPageLayout({
  title,
  children,
  permissions,
  breadcrumbs,
  headerAction,
}: AdminPageLayoutProps): React.ReactElement {
  const content = (
    <div className="flex flex-col gap-6 p-6">
      <div className="flex items-center justify-between">
        <div className="flex flex-col gap-1">
          {breadcrumbs && breadcrumbs.length > 0 ? (
            <nav className="flex gap-1 text-sm text-gray-500">
              {breadcrumbs.map((crumb, i) => (
                <span key={i}>
                  {crumb.href ? (
                    <a href={crumb.href} className="hover:underline">{crumb.label}</a>
                  ) : (
                    <span>{crumb.label}</span>
                  )}
                  {i < breadcrumbs.length - 1 ? <span className="mx-1">/</span> : null}
                </span>
              ))}
            </nav>
          ) : null}
          <h1 className="text-2xl font-semibold">{title}</h1>
        </div>
        {headerAction ? <div>{headerAction}</div> : null}
      </div>
      {children}
    </div>
  );

  if (permissions && permissions.length > 0) {
    return <PermissionGuard permissions={permissions}>{content}</PermissionGuard>;
  }
  return content;
}

export type { AdminPageLayoutProps, BreadcrumbItem };
```

---

### routeBuilders

Utility object with factory functions for all app routes. Prevents hardcoded strings from scattering across the codebase.

**Key contract:** One function per route. Functions with an ID parameter take a `number` or `string` as needed. Shared across features via `shared/routes/index.ts`.

```typescript
// shared/routes/index.ts
export const routeBuilders = {
  // Pattern: one entry per entity, cover list + detail + create + edit
  users: () => '/users',
  user: (id: number) => `/users/${id}`,
  userCreate: () => '/users/create',
  userEdit: (id: number) => `/users/${id}/edit`,
};
```

> If `shared/routes/index.ts` does not exist, create it and add the entity routes for the current feature. Never hardcode route strings in components or cells — always use `routeBuilders`.

---

## Form Components

### AlertModal + CreateAlertModal + SaveAlertModal

Base modal for confirmation actions. `CreateAlertModal` and `SaveAlertModal` are thin wrappers that pre-fill variant — they are the components used directly in form features. All three are co-located in the same file (`AlertModal.tsx`).

**Key contract:** `loading=true` disables both buttons AND blocks `onOpenChange` — the modal cannot be dismissed while a mutation is in flight.

```tsx
'use client';
import * as React from 'react';

type AlertModalVariant = 'brand' | 'destructive' | 'success';

interface AlertModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  variant?: AlertModalVariant;
  icon?: React.ReactNode;
  title: string;
  description?: React.ReactNode;
  confirmLabel: string;
  cancelLabel?: string;
  onConfirm: () => void;
  loading?: boolean;
}

export default function AlertModal({
  open,
  onOpenChange,
  variant = 'brand',
  icon,
  title,
  description,
  confirmLabel,
  cancelLabel = 'Cancelar',
  onConfirm,
  loading = false,
}: AlertModalProps): React.ReactElement | null {
  if (!open) return null;

  function handleOpenChange(value: boolean) {
    if (!loading) onOpenChange(value);
  }

  const variantClass: Record<AlertModalVariant, string> = {
    brand: 'bg-blue-600',
    destructive: 'bg-red-600',
    success: 'bg-green-600',
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      onClick={() => handleOpenChange(false)}
    >
      <div
        className="w-full max-w-sm rounded-lg bg-white p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        {icon ? (
          <div className={`mb-4 flex h-12 w-12 items-center justify-center rounded-full ${variantClass[variant]} text-white`}>
            {icon}
          </div>
        ) : null}
        <h2 className="text-lg font-semibold">{title}</h2>
        {description ? <p className="mt-2 text-sm text-gray-600">{description}</p> : null}
        <div className="mt-6 flex justify-end gap-3">
          <button
            type="button"
            disabled={loading}
            onClick={() => handleOpenChange(false)}
            className="rounded-md border px-4 py-2 text-sm disabled:opacity-50"
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            disabled={loading}
            onClick={onConfirm}
            className={`rounded-md px-4 py-2 text-sm text-white disabled:opacity-50 ${variantClass[variant]}`}
          >
            {loading ? 'Cargando...' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}

type AlertModalWrapperProps = Omit<AlertModalProps, 'variant' | 'icon'>;

export function CreateAlertModal(props: AlertModalWrapperProps): React.ReactElement {
  return <AlertModal {...props} variant="brand" />;
}

export function SaveAlertModal(props: AlertModalWrapperProps): React.ReactElement {
  return <AlertModal {...props} variant="brand" />;
}

export type { AlertModalProps, AlertModalWrapperProps };
```

---

### DetailSection

Compound component that divides a form into labeled sections. Each section has a label column on the left and form content on the right.

**Key contract:** Always use `DetailSection.Label` and `DetailSection.Content` as children — never put content directly inside `DetailSection`. One `DetailSection` per logical group of fields.

```tsx
import * as React from 'react';

interface DetailSectionProps {
  children: React.ReactNode;
  className?: string;
}

interface LabelProps {
  title: string;
  description?: string;
  size?: 'sm' | 'lg';
}

interface ContentProps {
  children: React.ReactNode;
  className?: string;
}

function Label({ title, description, size = 'lg' }: LabelProps): React.ReactElement {
  return (
    <div className="w-64 shrink-0">
      <p className={size === 'lg' ? 'text-base font-medium' : 'text-sm font-medium'}>{title}</p>
      {description ? <p className="mt-1 text-sm text-gray-500">{description}</p> : null}
    </div>
  );
}

function Content({ children, className }: ContentProps): React.ReactElement {
  return (
    <div className={`flex-1 rounded-lg bg-gray-50 p-4 ${className ?? ''}`}>
      {children}
    </div>
  );
}

function DetailSection({ children, className }: DetailSectionProps): React.ReactElement {
  return (
    <div className={`flex gap-8 border-b pb-8 ${className ?? ''}`}>
      {children}
    </div>
  );
}

DetailSection.Label = Label;
DetailSection.Content = Content;

export default DetailSection;
export type { DetailSectionProps, LabelProps, ContentProps };
```

---

### FooterForm

Sticky footer for form pages. Buttons configured via config objects.

**Key contract:** `primaryButton` maps to the submit action, `secondaryButton` to a secondary action (e.g. deactivate in update mode). A button is hidden when its config is not provided — pass no `primaryButton` to hide the footer entirely in view mode.

```tsx
'use client';
import * as React from 'react';

interface FooterButtonConfig {
  text: string;
  type?: 'button' | 'submit' | 'reset';
  onClick?: () => void;
  disabled?: boolean;
}

interface FooterFormProps {
  primaryButton?: FooterButtonConfig;
  secondaryButton?: FooterButtonConfig;
}

export default function FooterForm({ primaryButton, secondaryButton }: FooterFormProps): React.ReactElement {
  return (
    <footer className="sticky bottom-0 z-10 flex items-center justify-end gap-3 border-t bg-white px-6 py-4">
      {secondaryButton ? (
        <button
          type={secondaryButton.type ?? 'button'}
          disabled={secondaryButton.disabled}
          onClick={secondaryButton.onClick}
          className="rounded-md border px-4 py-2 text-sm disabled:opacity-50"
        >
          {secondaryButton.text}
        </button>
      ) : null}
      {primaryButton ? (
        <button
          type={primaryButton.type ?? 'button'}
          disabled={primaryButton.disabled}
          onClick={primaryButton.onClick}
          className="rounded-md bg-blue-600 px-4 py-2 text-sm text-white disabled:opacity-50"
        >
          {primaryButton.text}
        </button>
      ) : null}
    </footer>
  );
}

export type { FooterFormProps, FooterButtonConfig };
```

---

### FormSkeleton

Loading placeholder shown inside `<Suspense>` while form data is loading.

**Key contract:** No props. Drop directly as the `fallback` of the `<Suspense>` that wraps the form.

```tsx
import * as React from 'react';

export default function FormSkeleton(): React.ReactElement {
  return (
    <div className="animate-pulse space-y-4 p-6">
      <div className="h-8 w-48 rounded bg-gray-200" />
      <div className="h-64 rounded bg-gray-200" />
    </div>
  );
}
```

---

### DniFormInput

Document identity input with type selector. Types: V (venezolano), E (extranjero), J (jurídico), G (gubernamental), P (pasaporte).

**Key contract:** `control` and `name` are react-hook-form props — this is a controlled field. The full value is a string combining type + number (e.g. `"V-12345678"`). Adapt the type options to the project's requirements.

```tsx
'use client';
import * as React from 'react';
import { useController, type Control, type FieldValues, type Path } from 'react-hook-form';

type DniType = 'V' | 'E' | 'J' | 'G' | 'P';
const DNI_TYPES: DniType[] = ['V', 'E', 'J', 'G', 'P'];

interface DniFormInputProps<T extends FieldValues> {
  control: Control<T>;
  name: Path<T>;
  label?: string;
  placeholder?: string;
  disabled?: boolean;
}

export default function DniFormInput<T extends FieldValues>({
  control,
  name,
  label,
  placeholder = '12345678',
  disabled = false,
}: DniFormInputProps<T>): React.ReactElement {
  const { field, fieldState } = useController({ control, name });
  const [dniType, setDniType] = React.useState<DniType>('V');
  const [dniNumber, setDniNumber] = React.useState('');

  function handleTypeChange(type: DniType) {
    setDniType(type);
    field.onChange(`${type}-${dniNumber}`);
  }

  function handleNumberChange(e: React.ChangeEvent<HTMLInputElement>) {
    const value = e.target.value.replace(/\D/g, '');
    setDniNumber(value);
    field.onChange(`${dniType}-${value}`);
  }

  return (
    <div className="flex flex-col gap-1">
      {label ? <label className="text-sm font-medium">{label}</label> : null}
      <div className="flex gap-2">
        <select
          value={dniType}
          onChange={(e) => handleTypeChange(e.target.value as DniType)}
          disabled={disabled}
          className="rounded-md border px-2 py-1.5 text-sm"
        >
          {DNI_TYPES.map((t) => (
            <option key={t} value={t}>{t}</option>
          ))}
        </select>
        <input
          type="text"
          value={dniNumber}
          onChange={handleNumberChange}
          placeholder={placeholder}
          disabled={disabled}
          className="flex-1 rounded-md border px-3 py-1.5 text-sm disabled:opacity-50"
        />
      </div>
      {fieldState.error ? (
        <p className="text-sm text-red-500">{fieldState.error.message}</p>
      ) : null}
    </div>
  );
}

export type { DniFormInputProps };
```

---

### PhoneFormInput

Phone number input with country code selector.

> **External library:** In some projects this component is provided by an external library (e.g. `react-phone-number-input`, or a design system package). If the project already has a phone input, wrap it with `useController` from react-hook-form instead of using this fallback. Only build this from scratch when no library is available.

**Key contract:** `control` and `name` are react-hook-form props. The full value is a string combining country code + number (e.g. `"+58-4121234567"`). Adapt the country code list to the project's target markets.

```tsx
'use client';
import * as React from 'react';
import { useController, type Control, type FieldValues, type Path } from 'react-hook-form';

interface CountryCode {
  label: string;
  value: string;
}

const DEFAULT_COUNTRY_CODES: CountryCode[] = [
  { label: '🇻🇪 +58', value: '+58' },
  { label: '🇺🇸 +1', value: '+1' },
  { label: '🇨🇴 +57', value: '+57' },
  { label: '🇲🇽 +52', value: '+52' },
];

interface PhoneFormInputProps<T extends FieldValues> {
  control: Control<T>;
  name: Path<T>;
  label?: string;
  placeholder?: string;
  disabled?: boolean;
  countryCodes?: CountryCode[];
}

export default function PhoneFormInput<T extends FieldValues>({
  control,
  name,
  label,
  placeholder = '4121234567',
  disabled = false,
  countryCodes = DEFAULT_COUNTRY_CODES,
}: PhoneFormInputProps<T>): React.ReactElement {
  const { field, fieldState } = useController({ control, name });
  const [countryCode, setCountryCode] = React.useState(countryCodes[0]?.value ?? '+58');
  const [phoneNumber, setPhoneNumber] = React.useState('');

  function handleCodeChange(code: string) {
    setCountryCode(code);
    field.onChange(`${code}-${phoneNumber}`);
  }

  function handleNumberChange(e: React.ChangeEvent<HTMLInputElement>) {
    const value = e.target.value.replace(/\D/g, '');
    setPhoneNumber(value);
    field.onChange(`${countryCode}-${value}`);
  }

  return (
    <div className="flex flex-col gap-1">
      {label ? <label className="text-sm font-medium">{label}</label> : null}
      <div className="flex gap-2">
        <select
          value={countryCode}
          onChange={(e) => handleCodeChange(e.target.value)}
          disabled={disabled}
          className="rounded-md border px-2 py-1.5 text-sm"
        >
          {countryCodes.map((c) => (
            <option key={c.value} value={c.value}>{c.label}</option>
          ))}
        </select>
        <input
          type="tel"
          value={phoneNumber}
          onChange={handleNumberChange}
          placeholder={placeholder}
          disabled={disabled}
          className="flex-1 rounded-md border px-3 py-1.5 text-sm disabled:opacity-50"
        />
      </div>
      {fieldState.error ? (
        <p className="text-sm text-red-500">{fieldState.error.message}</p>
      ) : null}
    </div>
  );
}

export type { PhoneFormInputProps, CountryCode };
```

---

## Table Components

### SimpleTable (no column persistence)

Basic table without column configuration. Use when the project does not need per-user column visibility preferences.

**Key contract:** `titleBadge` in the top-left slot, `headerAction` in the top-right slot. `TableColumn<T>` for column definitions — never inline cell JSX in columns, extract to components.

```tsx
'use client';
import * as React from 'react';

export interface TableColumn<T> {
  id: string;
  header: React.ReactNode;
  cell: (row: T, index: number) => React.ReactNode;
  headerClassName?: string;
  cellClassName?: string;
}

interface SimpleTableProps<T> {
  columns: TableColumn<T>[];
  data: T[];
  loading?: boolean;
  page?: number;
  totalPages?: number;
  onPageChange?: (page: number) => void;
  titleBadge?: React.ReactNode;
  headerAction?: React.ReactNode;
}

export default function SimpleTable<T>({
  columns,
  data,
  loading = false,
  page = 1,
  totalPages = 1,
  onPageChange,
  titleBadge,
  headerAction,
}: SimpleTableProps<T>): React.ReactElement {
  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <div>{titleBadge}</div>
        <div>{headerAction}</div>
      </div>
      <div className="overflow-x-auto rounded-lg border">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b bg-gray-50">
              {columns.map((col) => (
                <th key={col.id} className={`px-4 py-3 text-left font-medium ${col.headerClassName ?? ''}`}>
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={columns.length} className="px-4 py-8 text-center text-gray-400">Cargando...</td></tr>
            ) : data.length === 0 ? (
              <tr><td colSpan={columns.length} className="px-4 py-8 text-center text-gray-400">No hay datos.</td></tr>
            ) : (
              data.map((row, i) => (
                <tr key={i} className="border-b last:border-0 hover:bg-gray-50">
                  {columns.map((col) => (
                    <td key={col.id} className={`px-4 py-3 ${col.cellClassName ?? ''}`}>{col.cell(row, i)}</td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
      {totalPages > 1 ? (
        <div className="flex items-center justify-end gap-2 text-sm">
          <button disabled={page <= 1} onClick={() => onPageChange?.(page - 1)} className="rounded border px-3 py-1 disabled:opacity-40">Anterior</button>
          <span>{page} / {totalPages}</span>
          <button disabled={page >= totalPages} onClick={() => onPageChange?.(page + 1)} className="rounded border px-3 py-1 disabled:opacity-40">Siguiente</button>
        </div>
      ) : null}
    </div>
  );
}

export type { SimpleTableProps };
```

### ConfigurableTableClientSide (server-persisted column config)

Column visibility preferences saved to the backend per user and per table identifier. **No reference implementation provided** — this variant requires backend infrastructure (a query to load saved config on mount and a mutation to persist changes). If the project doesn't already have this component, build it together with the backend endpoint before implementing the table feature.

**Key contract (same as SimpleTable):** `table` identifier string, `titleBadge` top-left slot, `headerAction` top-right slot, `TableColumn<T>` column definitions.

---

### TableFilterSearch

Debounced text input that syncs its value to a URL search param.

**Key contract:** No external debounce needed — handled internally. Always resets `page` to `1` on change.

```tsx
'use client';
import * as React from 'react';
import { useRouter, useSearchParams, usePathname } from 'next/navigation';

interface TableFilterSearchProps {
  searchParamKey: string;
  placeholder?: string;
  debounceMs?: number;
}

export default function TableFilterSearch({
  searchParamKey,
  placeholder = 'Buscar...',
  debounceMs = 300,
}: TableFilterSearchProps): React.ReactElement {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [value, setValue] = React.useState(searchParams.get(searchParamKey) ?? '');

  React.useEffect(() => {
    const timer = setTimeout(() => {
      const params = new URLSearchParams(searchParams.toString());
      if (value) params.set(searchParamKey, value);
      else params.delete(searchParamKey);
      params.set('page', '1');
      router.push(`${pathname}?${params.toString()}`);
    }, debounceMs);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  return (
    <input
      type="text"
      value={value}
      onChange={(e) => setValue(e.target.value)}
      placeholder={placeholder}
      className="rounded-md border px-3 py-1.5 text-sm outline-none"
    />
  );
}

export type { TableFilterSearchProps };
```

---

### TableFilterSimpleSelect

Select dropdown that syncs the selected value to a URL search param.

**Key contract:** Never include the "all" option in `options` — pass `allOptionLabel` and the component adds it internally. Always resets `page` to `1` on change.

```tsx
'use client';
import * as React from 'react';
import { useRouter, useSearchParams, usePathname } from 'next/navigation';

export interface TableFilterOption {
  label: string;
  value: string;
}

interface TableFilterSimpleSelectProps {
  searchParamKey: string;
  options: TableFilterOption[];
  placeholder: string;
  allOptionLabel?: string;
}

const ALL_VALUE = '__all__';

export default function TableFilterSimpleSelect({
  searchParamKey,
  options,
  placeholder,
  allOptionLabel,
}: TableFilterSimpleSelectProps): React.ReactElement {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const current = searchParams.get(searchParamKey) ?? ALL_VALUE;

  function handleChange(e: React.ChangeEvent<HTMLSelectElement>): void {
    const params = new URLSearchParams(searchParams.toString());
    if (e.target.value === ALL_VALUE) params.delete(searchParamKey);
    else params.set(searchParamKey, e.target.value);
    params.set('page', '1');
    router.push(`${pathname}?${params.toString()}`);
  }

  return (
    <select value={current} onChange={handleChange} className="rounded-md border px-3 py-1.5 text-sm outline-none">
      {allOptionLabel ? (
        <option value={ALL_VALUE}>{allOptionLabel}</option>
      ) : (
        <option value={ALL_VALUE} disabled>{placeholder}</option>
      )}
      {options.map((opt) => (
        <option key={opt.value} value={opt.value}>{opt.label}</option>
      ))}
    </select>
  );
}

export type { TableFilterSimpleSelectProps, TableFilterOption };
```

