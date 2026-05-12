---
name: dev-table-feature
description: Use when building a paginated, filterable, configurable table feature that spans backend + frontend. Use when the task involves a view<Entity> or list<Entity> feature with server-side pagination, URL-based filters, and column configuration.
---

# Table Feature

## When to Use

- Building a new paginated list/table for an entity
- Adding filters to an existing table
- Creating a `view<Entities>` feature
- Wiring a backend paginated endpoint to a frontend table
- **For CRUD forms** (create/edit/view) → use **dev-form-engineering** skill instead

## Output Artifact

A complete `view<Entity>` vertical slice in the target project — backend paginated endpoint + frontend table with URL-driven filters.

## Stack Activation Gate

Detect the active stack from the project's package files. State it explicitly: "Active stack: {name}".

| Stack | Detection signal | Reference file | Components reference |
|---|---|---|---|
| Next.js | `next` in `package.json` (not Angular, not React Native) | `references/nextjs.md` | `stacks/nextjs/agent_docs/references/components.md` |
| React Native | `react-native` in `package.json` | TODO — ask the user how tables and pagination are handled in their project | TODO |
| Angular | `angular.json` present or `@angular/core` in `package.json` | TODO — ask the user how tables and pagination are handled in their project | TODO |

Note both the **reference file path** and the **components reference path** for the active stack. Do not read them yet — the Prerequisites Gate controls when.

## Project Prerequisites Gate

**Run this immediately after stack detection, before reading the reference file or generating any code.**

**Scope:** The component roles, file patterns, and fallback search terms below apply to the **Next.js** stack. For stacks marked TODO (React Native, Angular): this gate does not apply until the user confirms how tables and pagination are structured in their project (via the Stack Activation Gate). Use that information to determine which components to look for instead.

**Step 1 — Find an existing `view<Entity>` feature** in the project:

```
find . -name "*TableWidget.tsx" -not -path "*/node_modules/*" | head -3
```

- If found: read the Table widget file. Extract all component names from its imports — these are your Component Map values.
- If not found: grep for the names in the table below as fallback.

| Role | Fallback search terms |
|---|---|
| Table (server-persisted column config) | `ConfigurableTable`, `ConfigurableTableClientSide` |
| Table (simple, no column persistence) | `DataTable`, `Table`, `BaseTable` |
| Text search filter | `TableFilterSearch`, `SearchInput` |
| Select filter | `TableFilterSimpleSelect`, `TableFilterSelect` |
| Safe result guard | `QueryResultGuard`, `ResultGuard` |
| SSR prefetch wrapper (Next.js only) | `PrefetchBoundary`, `HydrationBoundary` |
| Permission gate | `PermissionGuard`, `WithPermission`, `CanAccess` |
| Page layout / shell | `AdminPageLayout`, `PageLayout`, `AppLayout` |

**Step 2 — Output the Component Map** before doing anything else:

```
Component Map:
- Table component:     <name or "not found">
- Text search filter:  <name or "not found">
- Select filter:       <name or "not found">
- Safe result guard:   <name or "not found">
- SSR prefetch wrapper: <name or "not found">
- Permission guard:    <name or "not found">
- Page layout:         <name or "not found">
```

**Step 3 — Resolve gaps.** For each "not found":

- For filters, safe result guard, SSR prefetch wrapper, permission guard, and page layout: show the reference implementation from the **components reference** noted in the Stack Activation Gate, and ask if they want to create it or have an equivalent with a different name.

- For the **table component** specifically — ask first:
  > "Does this project need column visibility preferences saved per user (stored in the backend)?"
  - **Yes** → the project needs `ConfigurableTableClientSide`. This variant **requires backend infrastructure** (a user-preferences endpoint). If it doesn't exist yet, stop and tell the developer: "This component requires a backend endpoint to persist column preferences. We'll need to build that first — do you want to proceed?" Do not generate the table code until the developer confirms.
  - **No** → use the `SimpleTable` variant from the **components reference** noted in the Stack Activation Gate.

**STOP.** Output only the Component Map and gap questions above. Do not propose any implementation or generate any code until the user responds to every gap.

**Step 4 — Read** the reference file identified in the Stack Activation Gate. That file may link to additional required reading — read those documents too before generating any code. Generate code using the names from the Component Map — not the names in the reference file examples.

> If the active stack is marked TODO in the Stack Activation Gate, skip the Prerequisites Gate entirely. Ask the user to describe how tables and pagination are structured in their project, then derive the Component Map from their answer.

## Related Skills

- **dev-form-engineering** — for the create/edit/view form that this table links to. **If building both together:** implement the form feature first (`manage<Entity>`) — the table imports `MANAGE_<ENTITY>_PERMISSIONS` and `routeBuilders` from the form feature.
- **dev-frontend-ui-engineering** — for component architecture and design system
- **dev-test-driven-development** — for testing the use case and transforms
- **dev-api-and-interface-design** — for designing the backend pagination contract the table consumes
