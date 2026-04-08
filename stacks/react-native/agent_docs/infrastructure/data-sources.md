# Data Sources

A data source is a class that knows how to communicate with a single external system. It holds the raw mechanics of that communication: building request URLs, setting headers, calling `axios.get()`, reading from `AsyncStorage`, or writing to `expo-secure-store`. It knows nothing about domain entities or business rules. It returns raw data — JSON objects, strings, `null` — and it throws exceptions when communication fails.

The data source is the lowest-level abstraction in the infrastructure layer. Above it, repository implementations compose data sources, catch their exceptions, and map raw data to domain types. Below it is the network, the device storage, and the platform APIs.

---

## Abstract Data Source Pattern

Data sources can be defined with an abstract class that declares the interface and a concrete class that implements it. This allows mock data sources to be substituted during testing.

```typescript
// ✅ Good — Abstract data source defines the API surface
// src/infrastructure/data-sources/user-api-data-source.ts

export abstract class AbstractUserApiDataSource {
  abstract getUser(id: string): Promise<unknown>;
  abstract getUserByEmail(email: string): Promise<unknown>;
  abstract updateUser(id: string, data: unknown): Promise<unknown>;
  abstract deleteUser(id: string): Promise<void>;
}
```

---

## REST Data Source with Axios

The HTTP client (`axios` instance) is configured once and shared across data sources. Each data source receives it through constructor injection.

```typescript
// ✅ Good — Shared Axios client with base configuration
// src/infrastructure/http/axios-client.ts

import axios from 'axios';
import { API_BASE_URL } from '@/lib/constants';

export const axiosClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

axiosClient.interceptors.request.use((config) => {
  // Auth token is attached here (reading from secure storage or memory)
  return config;
});

axiosClient.interceptors.response.use(
  (response) => response,
  (error) => {
    // Re-throw as a standard Response-like object for consistent catching
    return Promise.reject(error.response ?? error);
  },
);
```

```typescript
// ✅ Good — User API data source
// src/infrastructure/data-sources/user-api-data-source.ts

import type { AxiosInstance } from 'axios';

export class UserApiDataSource {
  constructor(private readonly http: AxiosInstance) {}

  async getUser(id: string): Promise<unknown> {
    const response = await this.http.get(`/users/${id}`);
    return response.data;
  }

  async getUserByEmail(email: string): Promise<unknown> {
    const response = await this.http.get('/users', { params: { email } });
    return response.data;
  }

  async updateUser(id: string, data: unknown): Promise<unknown> {
    const response = await this.http.patch(`/users/${id}`, data);
    return response.data;
  }

  async deleteUser(id: string): Promise<void> {
    await this.http.delete(`/users/${id}`);
  }

  async uploadAvatar(userId: string, uri: string): Promise<unknown> {
    const formData = new FormData();
    formData.append('avatar', { uri, type: 'image/jpeg', name: 'avatar.jpg' } as unknown as Blob);
    const response = await this.http.post(`/users/${userId}/avatar`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  }
}
```

---

## `expo-secure-store` for Sensitive Data

Use `expo-secure-store` for authentication tokens, refresh tokens, and any sensitive credentials. It encrypts data using the platform's secure enclave.

```typescript
// ✅ Good — Secure storage data source for auth tokens
// src/infrastructure/data-sources/secure-storage-data-source.ts

import * as SecureStore from 'expo-secure-store';

const AUTH_TOKEN_KEY = 'auth_access_token';
const REFRESH_TOKEN_KEY = 'auth_refresh_token';

export class SecureStorageDataSource {
  async getAuthToken(): Promise<string | null> {
    return SecureStore.getItemAsync(AUTH_TOKEN_KEY);
  }

  async setAuthToken(token: string): Promise<void> {
    await SecureStore.setItemAsync(AUTH_TOKEN_KEY, token);
  }

  async getRefreshToken(): Promise<string | null> {
    return SecureStore.getItemAsync(REFRESH_TOKEN_KEY);
  }

  async setRefreshToken(token: string): Promise<void> {
    await SecureStore.setItemAsync(REFRESH_TOKEN_KEY, token);
  }

  async clearAuthTokens(): Promise<void> {
    await Promise.all([
      SecureStore.deleteItemAsync(AUTH_TOKEN_KEY),
      SecureStore.deleteItemAsync(REFRESH_TOKEN_KEY),
    ]);
  }
}
```

---

## `AsyncStorage` for Non-Sensitive Persistence

Use `AsyncStorage` for user preferences, cached UI state, and any non-sensitive data that should survive app restarts.

```typescript
// ✅ Good — Preferences data source using AsyncStorage
// src/infrastructure/data-sources/preferences-data-source.ts

import AsyncStorage from '@react-native-async-storage/async-storage';

const THEME_KEY = 'user_preference_theme';
const LANGUAGE_KEY = 'user_preference_language';

export class PreferencesDataSource {
  async getTheme(): Promise<string | null> {
    return AsyncStorage.getItem(THEME_KEY);
  }

  async setTheme(theme: 'light' | 'dark' | 'system'): Promise<void> {
    await AsyncStorage.setItem(THEME_KEY, theme);
  }

  async getLanguage(): Promise<string | null> {
    return AsyncStorage.getItem(LANGUAGE_KEY);
  }

  async setLanguage(locale: string): Promise<void> {
    await AsyncStorage.setItem(LANGUAGE_KEY, locale);
  }

  async clearPreferences(): Promise<void> {
    await AsyncStorage.multiRemove([THEME_KEY, LANGUAGE_KEY]);
  }
}
```

---

## Error Catching in Data Sources

Data sources throw exceptions when they fail — they do not return `Result`. The repository implementation above them is responsible for catching these exceptions and mapping them to domain errors. This keeps data sources simple and focused on communication mechanics.

```typescript
// ✅ Good — Data source throws, repository catches
// src/infrastructure/data-sources/order-api-data-source.ts

import type { AxiosInstance } from 'axios';

export class OrderApiDataSource {
  constructor(private readonly http: AxiosInstance) {}

  // Throws AxiosError on failure — repository will catch and map
  async getOrder(id: string): Promise<unknown> {
    const response = await this.http.get(`/orders/${id}`);
    return response.data;
  }

  async getOrdersByUserId(userId: string): Promise<unknown> {
    const response = await this.http.get(`/orders`, { params: { userId } });
    return response.data;
  }

  async createOrder(data: unknown): Promise<unknown> {
    const response = await this.http.post('/orders', data);
    return response.data;
  }

  async cancelOrder(id: string): Promise<void> {
    await this.http.post(`/orders/${id}/cancel`);
  }
}
```

---

## Anti-Patterns

### ❌ Data source returning domain entities

```typescript
// ❌ Bad — Data source maps raw data to entities
export class UserApiDataSource {
  async getUser(id: string): Promise<User> {
    const response = await this.http.get(`/users/${id}`);
    return {                        // Mapping belongs in DTO/repository, not here
      id: response.data.id,
      email: response.data.email_address,
      displayName: response.data.full_name,
    };
  }
}
```

Data sources return `unknown` or raw typed API shapes. Mapping is the repository's concern.

### ❌ Data source catching and mapping to domain errors

```typescript
// ❌ Bad — Catching happens in the wrong layer
export class UserApiDataSource {
  async getUser(id: string): Promise<Result<unknown, UserError>> {
    try {
      const response = await this.http.get(`/users/${id}`);
      return ok(response.data);
    } catch {
      return err({ type: 'USER_NOT_FOUND', id }); // Domain error in data source
    }
  }
}
```

The data source's job is communication. Error mapping to domain errors is the repository implementation's job.

### ❌ Using `AsyncStorage` for sensitive data

```typescript
// ❌ Bad — Auth token in unencrypted storage
import AsyncStorage from '@react-native-async-storage/async-storage';

await AsyncStorage.setItem('auth_token', token); // Not encrypted — use SecureStore
```

---

[← Infrastructure Layer](./infrastructure.md) | [Index](../README.md) | [Next: DTOs →](./dtos.md)
