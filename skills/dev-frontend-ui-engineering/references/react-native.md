# React Native + Expo — Standards Reference

## Architecture

Clean Architecture with four concentric layers. Dependencies always point inward — Presentation → Application → Domain. Domain knows nothing about the outside world.

```
┌───────────────────────────────────────────┐
│              PRESENTATION                 │  Screens, Components, Hooks, Navigation
│           (React Native, Expo)            │
├───────────────────────────────────────────┤
│              INFRASTRUCTURE               │  Data Sources, Repository Impls, DTOs
│         (Axios, AsyncStorage, Expo)       │
├───────────────────────────────────────────┤
│               APPLICATION                │  Use Cases — orchestration
│              (Pure TypeScript)            │
├───────────────────────────────────────────┤
│                  DOMAIN                   │  Entities, Repository Interfaces
│              (Pure TypeScript)            │
└───────────────────────────────────────────┘
```

**Library stack:** React Native + Expo · Expo Router · TanStack React Query (server state) · Zustand (UI state) · Zod (validation) · NativeWind (styling) · Vitest (tests)

## Folder Structure

```
src/
├── app/                          # Expo Router — thin route wrappers only
│   ├── _layout.tsx               # Composition root (wires DI)
│   ├── (auth)/
│   └── (main)/
├── domain/
│   ├── entities/                 # Readonly TypeScript interfaces
│   ├── enums/                    # const object pattern + string literal unions
│   ├── errors/                   # Domain error types
│   ├── repositories/             # Interfaces (IUserRepository)
│   └── validators/               # Zod schemas
├── application/
│   └── use-cases/
│       └── user/
│           └── get-user-profile-use-case.ts
├── infrastructure/
│   ├── data-sources/             # REST, AsyncStorage, expo-secure-store
│   ├── dtos/                     # Zod-validated, toEntity(), fromEntity()
│   ├── repositories/             # Implements domain interfaces
│   └── http/                     # Axios client
└── presentation/
    ├── context/                  # UseCaseContext — DI bridge
    ├── features/
    │   └── <feature>/
    │       ├── screens/          # Expo Router delegates to these
    │       ├── components/       # Presentational, NativeWind
    │       └── hooks/            # TanStack Query wrappers + use case calls
    └── shared/                   # Cross-feature: components, hooks, stores
```

**Path alias:** `@/` resolves to `src/`. No relative `../` traversal across layers.

## Layer Rules

### Domain — CAN / CANNOT

| CAN | CANNOT |
|---|---|
| Define entity interfaces | Import from React Native or Expo |
| Define repository interfaces | Make HTTP calls |
| Define domain error types | Access AsyncStorage |
| Define Zod validators | Know about UI state |

### Application — CAN / CANNOT

| CAN | CANNOT |
|---|---|
| Import domain interfaces and types | Import from React Native or Expo |
| Orchestrate repositories | Know about HTTP or persistence |
| Return `Result<T, E>` | Import Zustand or TanStack Query |

### Infrastructure — CAN / CANNOT

| CAN | CANNOT |
|---|---|
| Implement domain repository interfaces | Contain business logic |
| Import HTTP clients (Axios, fetch) | Import from Presentation |
| Map DTOs to domain entities | Return raw API responses upward |
| Catch raw exceptions, map to domain failures | Throw uncaught exceptions outward |

### Presentation — CAN / CANNOT

| CAN | CANNOT |
|---|---|
| Use React Native and Expo components | Call infrastructure directly |
| Use TanStack Query and Zustand | Contain business logic |
| Invoke use cases via context | Import Axios or data sources |

## Dependency Injection

Composition root wires implementations into the React Context tree:

```typescript
// app/_layout.tsx
export default function RootLayout() {
  const userDataSource = new UserApiDataSource();
  const userRepository = new UserRepositoryImpl(userDataSource);
  const getUserProfile = new GetUserProfileUseCase(userRepository);

  return (
    <UseCaseContext.Provider value={{ getUserProfile }}>
      <Stack />
    </UseCaseContext.Provider>
  );
}

// presentation/context/use-case-context.ts
export const UseCaseContext = createContext<UseCaseContextValue | null>(null);
export function useUseCaseContext(): UseCaseContextValue {
  const ctx = useContext(UseCaseContext);
  if (!ctx) throw new Error('useUseCaseContext must be inside UseCaseContext.Provider');
  return ctx;
}
```

## State Management

| State type | Tool |
|---|---|
| Server state (remote data with caching) | TanStack React Query |
| App-wide local UI state | Zustand |
| Component-scoped ephemeral state | `useState` |

Never `useEffect` + `fetch` for server data.

## Presentation: Screens and Components

**Route files** are thin delegates — no business logic:
```typescript
// app/(main)/profile/[id].tsx
export default function UserProfileRoute() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <UserProfileScreen userId={id} />;
}
```

**Hooks** wrap use cases via TanStack Query:
```typescript
export function useUserProfile(userId: string) {
  const { getUserProfile } = useUseCaseContext();
  return useQuery({
    queryKey: ['user-profile', userId],
    queryFn: () => getUserProfile.execute(userId),
  });
}
```

**Screens** handle loading/error/empty. **Components** are pure presentational:
```typescript
export function UserProfileScreen({ userId }: { userId: string }) {
  const { data, isLoading, isError } = useUserProfile(userId);
  if (isLoading) return <LoadingSpinner />;
  if (isError) return <ErrorState />;
  return <UserProfileCard user={data} />;
}
```

**Cross-feature components** go in `presentation/shared/components/` — never import from another feature's `components/`.

## Infrastructure: DTOs

Always validate API responses at the boundary:

```typescript
const UserDtoSchema = z.object({ id: z.string(), email: z.string(), name: z.string() });

export function toEntity(raw: unknown): User {
  const dto = UserDtoSchema.parse(raw); // validate here
  return { id: dto.id, email: dto.email, name: dto.name };
}
```

## Infrastructure: Repositories

```typescript
export class UserRepositoryImpl implements IUserRepository {
  constructor(private readonly dataSource: UserApiDataSource) {}

  async findById(id: string): Promise<User | null> {
    try {
      const response = await this.dataSource.getById(id);
      return toEntity(response.data);
    } catch {
      return null;
    }
  }
}
```

## Error Handling

Expected failures are modeled as values, never thrown:

```typescript
type Result<T, E> = { success: true; data: T } | { success: false; error: E };

// Infrastructure — catch, map to domain Result
async findById(id: string): Promise<Result<User, UserError>> {
  try {
    return { success: true, data: toEntity(await this.dataSource.getById(id)) };
  } catch {
    return { success: false, error: new UserNotFoundError(id) };
  }
}

// Presentation — handle result
const result = await getUserProfile.execute(userId);
if (!result.success) return <ErrorState message={result.error.message} />;
```

## Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Screens | PascalCase + `Screen` | `UserProfileScreen.tsx` |
| Components | PascalCase + descriptive | `UserAvatar.tsx` |
| Hooks | `use` + camelCase | `use-user-profile.ts` |
| Use cases | PascalCase + `UseCase` | `GetUserProfileUseCase.ts` |
| DTOs | PascalCase + `Dto` | `UserDto.ts` |
| Repository interfaces | `I` prefix | `IUserRepository.ts` |

## Red Flags

- Business logic inside a Screen's render (belongs in use case)
- `useEffect` + `fetch` for server data (use TanStack Query)
- `import from 'react-native'` or `import from 'expo-*'` in `domain/` or `application/`
- Use case importing Axios or a data source directly
- Cross-feature component imports (use `presentation/shared/`)
- `../../../` relative imports traversing layers

## Verification Checklist

- [ ] TypeScript compilation passes (`npm run typecheck` or `tsc --noEmit`)
- [ ] No `react-native` or `expo-*` imports in `domain/` or `application/`
- [ ] Use cases injected via context — not directly instantiated in components
- [ ] Server state managed by TanStack Query — no `useEffect` + `fetch`
- [ ] All async fallible operations return a Result type (no thrown business errors)
- [ ] `@/` path alias used everywhere (no `../../../`)
- [ ] Cross-feature shared components in `presentation/shared/`
