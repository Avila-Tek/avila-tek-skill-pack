# Next.js — Testing Utilities

Reference implementations for E2E testing infrastructure. Load this file when writing or debugging Cypress tests — not needed during feature development.

---

## MockHttpClient

In-process JS interceptor that handles API calls before they reach the network. Used in E2E tests (Cypress) to stub responses without a real backend. Implements the same `HttpClient` interface as `SafeFetchClient` — swap it in when `NEXT_PUBLIC_API_MOCKING=enabled`.

**Key contract:**
- Handlers are keyed by **path only** (not method) — `mockResponse('/v1/users', { data })` applies to any HTTP verb on that path.
- `window.__mockClient__` is a **broadcast facade**, not the client directly — multiple `MockHttpClient` instances can be registered (e.g. one in `packages/features`, one in the app). Each Cypress command goes through the facade which forwards to all registered clients.
- `public calls: MockCall[]` — array populated on every request, useful for asserting that a call was made.
- Errors use a sentinel `{ __mockError: string }` in the response data, detected in `handleRequest`.

**`packages/services/src/http/adapters/mockHttp.client.ts`**

```typescript
import type { Safe } from '@repo/utils';
import type { HttpClient, HttpMethod, HttpRequestOptions, InferResponseType, QueryParams, ZodLikeSchema } from '../port/httpClient.port';
import { httpMethodEnumObject } from '../port/httpClient.port';

interface MockResponse<T = unknown> {
  data: T;
}

interface MockCall {
  method: string;
  path: string;
  schema?: ZodLikeSchema;
  body?: unknown;
  params?: QueryParams;
  options?: HttpRequestOptions;
}

export class MockHttpClient implements HttpClient {
  public calls: MockCall[] = [];
  private responses = new Map<string, MockResponse>();
  private defaultResponse: MockResponse = { data: {} };

  mockResponse<T>(path: string, response: MockResponse<T>): void {
    this.responses.set(path, response);
  }

  mockError(path: string, error: string): void {
    this.responses.set(path, { data: { __mockError: error } });
  }

  setDefaultResponse<T>(response: MockResponse<T>): void {
    this.defaultResponse = response;
  }

  reset(): void {
    this.calls = [];
    this.responses.clear();
  }

  async get<T = unknown, TSchema extends ZodLikeSchema | undefined = undefined>(
    path: string, params?: QueryParams, options?: HttpRequestOptions, schema?: TSchema
  ): Promise<Safe<InferResponseType<T, TSchema>>> {
    return this.handleRequest({ method: httpMethodEnumObject.GET, path, params, options, schema });
  }

  async post<T = unknown, TSchema extends ZodLikeSchema | undefined = undefined>(
    path: string, body?: unknown, params?: QueryParams, options?: HttpRequestOptions, schema?: TSchema
  ): Promise<Safe<InferResponseType<T, TSchema>>> {
    return this.handleRequest({ method: httpMethodEnumObject.POST, path, body, params, options, schema });
  }

  async put<T = unknown, TSchema extends ZodLikeSchema | undefined = undefined>(
    path: string, body?: unknown, params?: QueryParams, options?: HttpRequestOptions, schema?: TSchema
  ): Promise<Safe<InferResponseType<T, TSchema>>> {
    return this.handleRequest({ method: httpMethodEnumObject.PUT, path, body, params, options, schema });
  }

  async patch<T = unknown, TSchema extends ZodLikeSchema | undefined = undefined>(
    path: string, body?: unknown, params?: QueryParams, options?: HttpRequestOptions, schema?: TSchema
  ): Promise<Safe<InferResponseType<T, TSchema>>> {
    return this.handleRequest({ method: httpMethodEnumObject.PATCH, path, body, params, options, schema });
  }

  async delete<T = unknown, TSchema extends ZodLikeSchema | undefined = undefined>(
    path: string, params?: QueryParams, options?: HttpRequestOptions, schema?: TSchema
  ): Promise<Safe<InferResponseType<T, TSchema>>> {
    return this.handleRequest({ method: httpMethodEnumObject.DELETE, path, params, options, schema });
  }

  private handleRequest<T, TSchema extends ZodLikeSchema | undefined>({
    method, path, body, params, options, schema,
  }: { method: HttpMethod; path: string; body?: unknown; params?: QueryParams; options?: HttpRequestOptions; schema?: TSchema }): Promise<Safe<InferResponseType<T, TSchema>>> {
    this.calls.push({ method, path, body, params, options });
    const response = this.responses.get(path) ?? this.defaultResponse;

    // Error sentinel
    if (response.data && typeof response.data === 'object' && '__mockError' in response.data) {
      return Promise.resolve({
        success: false,
        error: (response.data as { __mockError: string }).__mockError,
      });
    }

    return Promise.resolve({ success: true, data: response.data as InferResponseType<T, TSchema> });
  }
}
```

**`packages/services/src/lib/mocking.ts`** — helper to detect mock mode:

```typescript
export function isMockingEnabled(): boolean {
  return process.env.NEXT_PUBLIC_API_MOCKING === 'enabled';
}
```

**`packages/features/src/mocks/registerClient.ts`** — facade that broadcasts to all registered clients:

```typescript
import type { MockHttpClient } from '@repo/services';

type MockFacade = {
  mockError: (path: string, error: string) => void;
  mockResponse: (path: string, response: { data: unknown }) => void;
};

type MockWindow = Window & {
  __mockClient__?: MockFacade;
  __mockClientRegistry__?: MockHttpClient[];
};

/**
 * Registers a MockHttpClient in a broadcast facade on window.__mockClient__.
 * Multiple clients can be registered (e.g. features + app-level).
 * Each Cypress command goes through the facade which calls every registered client.
 */
export function registerMockClient(client: MockHttpClient): void {
  if (typeof window === 'undefined') return;
  const win = window as MockWindow;
  if (!win.__mockClientRegistry__) {
    win.__mockClientRegistry__ = [];
    win.__mockClient__ = {
      mockError: (path, error) =>
        win.__mockClientRegistry__!.forEach((c) => c.mockError(path, error)),
      mockResponse: (path, response) =>
        win.__mockClientRegistry__!.forEach((c) => c.mockResponse(path, response)),
    };
  }
  win.__mockClientRegistry__.push(client);
}
```

**`packages/features/src/mocks/client.ts`** — shared mock client (auth, catalogs):

```typescript
import { MockHttpClient } from '@repo/services';
import { registerMockClient } from './registerClient';

export function buildFeaturesMockClient(): MockHttpClient {
  const client = new MockHttpClient();

  // Register default responses for shared routes
  client.mockResponse('/v1/auth/sign-in', { data: authMockResponses.signIn });
  client.mockResponse('/v1/auth/current-user', { data: authMockResponses.currentUser });
  // ... other shared routes

  registerMockClient(client);
  return client;
}
```

**`apps/<app>/src/mocks/client.ts`** — app-level mock client (feature-specific routes):

```typescript
import { MockHttpClient } from '@repo/services';
import { registerMockClient } from '@repo/features/mocks/registerClient';

export function buildMockClient(): MockHttpClient {
  const client = new MockHttpClient();

  client.mockResponse('/v1/users/paginate', { data: userMockResponses.paginate });
  client.mockResponse('/v1/users/1', { data: userMockResponses.getById });
  // ... other app routes

  registerMockClient(client);
  return client;
}
```

**Cypress commands** — `apps/<app>/cypress/support/commands.ts`:

```typescript
type MockClient = {
  mockError: (path: string, error: string) => void;
  mockResponse: (path: string, response: { data: unknown }) => void;
};

function isMockingEnabled(): boolean {
  return Cypress.env('API_MOCKING') === 'enabled';
}

// Low-level: program a single client path — call after cy.visit()
Cypress.Commands.add('setMockError', (path: string, error: string) => {
  cy.window().then((win: Window & { __mockClient__?: MockClient }) => {
    win.__mockClient__?.mockError(path, error);
  });
});

Cypress.Commands.add('setMockResponse', (path: string, data: unknown) => {
  cy.window().then((win: Window & { __mockClient__?: MockClient }) => {
    win.__mockClient__?.mockResponse(path, { data });
  });
});

// Environment-aware: mock mode → MockHttpClient facade; real mode → cy.intercept()
Cypress.Commands.add('apiError', (method: InterceptMethod, path: string, statusCode: number, error: string) => {
  if (isMockingEnabled()) {
    cy.setMockError(path, error);
  } else {
    cy.intercept(method, `**${path}`, { statusCode, body: { success: false, error } });
  }
});

Cypress.Commands.add('apiResponse', (method: InterceptMethod, path: string, data: unknown) => {
  if (isMockingEnabled()) {
    cy.setMockResponse(path, data);
  } else {
    cy.intercept(method, `**${path}`, { statusCode: 200, body: { success: true, data } });
  }
});
```

**`apps/<app>/cypress.config.ts`** — forward the env variable to Cypress:

```typescript
import { defineConfig } from 'cypress';
import { config as loadEnv } from 'dotenv';
import { resolve } from 'path';

// Cypress runs in a separate Node.js process — it does not read .env files on its own.
loadEnv({ path: resolve(__dirname, '.env.local') });

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:3001',
    env: {
      // cy.apiError / cy.apiResponse check this to choose MockHttpClient vs cy.intercept
      API_MOCKING: process.env.NEXT_PUBLIC_API_MOCKING,
    },
  },
});
```

**Switching modes** — edit `apps/<app>/.env.local`:
- `NEXT_PUBLIC_API_MOCKING=enabled` → MockHttpClient, no backend needed
- variable unset → real HTTP, backend required
