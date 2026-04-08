# Data Sources

Data sources are the **lowest-level classes** in the application. They communicate directly with external systems: REST APIs, GraphQL endpoints, Firebase, device storage, analytics SDKs, etc.

## Naming

### Interfaces

Data source interfaces **must** be prefixed with `I` and use one of the following suffixes depending on the nature of the service:

| Suffix | When to use |
|---|---|
| `Api` | External API (REST, GraphQL) |
| `Service` | Third-party SDK wrapper (Firebase, Analytics, etc.) |
| `DataSource` | Device storage, local database, shared preferences |

```dart
abstract interface class IUserApi { }
abstract interface class IAnalyticsService { }
abstract interface class IDeviceStorageDataSource { }
```

### Implementations

Implementation names **must** use the same base name and suffix as the interface, prefixed with the protocol or technology:

```dart
// REST implementations
class UserApiRest implements IUserApi { }
class OrdersApiRest implements IOrdersApi { }

// GraphQL implementations
class UserApiGraphQL implements IUserApi { }
class CoreApiGraphQL implements ICoreApi { }

// Third-party or named implementations
class AuthFirebaseService implements IAuthService { }
class SharedPreferencesDataSource implements IDeviceStorageDataSource { }

// Mock implementations (for testing)
class UserApiMock implements IUserApi { }
```

## Constructors

### URL Validation

Data sources that communicate over HTTP **must** receive the API base URL as a constructor parameter and validate it with `assert` statements:

```dart
class UserApiRest implements IUserApi {
  UserApiRest(String url, this._client)
      : assert(
          url.startsWith(RegExp(r'^https?://')),
          'URL must start with "http://" or "https://"',
        ),
        assert(
          !url.endsWith('/'),
          'URL must not end with "/"',
        ),
        _baseUrl = url;

  final String _baseUrl;
  final http.Client _client;
}
```

For GraphQL data sources, additionally assert that the URL ends with `/graphql`:

```dart
assert(
  url.endsWith('/graphql'),
  'GraphQL URL must end with "/graphql"',
),
```

### HTTP Client Injection

HTTP-based data sources **must** receive an `http.Client` as a constructor parameter instead of creating it internally. This makes the data source testable:

```dart
import 'package:http/http.dart' as http;

class OrdersApiRest implements IOrdersApi {
  OrdersApiRest(String url, http.Client client)
      : _baseUrl = url,
        _client = client;

  final String _baseUrl;
  final http.Client _client;
}
```

## Methods

### Return Types

Data source methods return **raw, unprocessed data** — typically `Future<Map<String, dynamic>>`, `Future<List<Map<String, dynamic>>>`, or `Future<void>`. They do **not** return domain entities or `Either` types.

Mapping raw data to DTOs and then to domain entities is the responsibility of the repository implementation.

```dart
abstract interface class IUserApi {
  Future<Map<String, dynamic>> getUser(String id);
  Future<List<Map<String, dynamic>>> getUsers();
  Future<void> updateUser(String id, Map<String, dynamic> body);
}
```

### Exceptions

Data sources **may throw exceptions** for error conditions. These exceptions are caught and mapped to domain errors by the [repository implementation](./repositories.md). Do not use `Either` in data sources.

```dart
class UserApiRest implements IUserApi {
  @override
  Future<Map<String, dynamic>> getUser(String id) async {
    final response = await _client.get(Uri.parse('$_baseUrl/users/$id'));

    if (response.statusCode == 404) throw const NotFoundException();
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) throw ServerException(response.statusCode);

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
```

## Complete Example

```dart
// infrastructure/data_sources/user/i_user_api.dart

abstract interface class IUserApi {
  Future<Map<String, dynamic>> getUser(String id);
  Future<List<Map<String, dynamic>>> getUsers();
  Future<void> updateUser(String id, Map<String, dynamic> body);
  Future<void> deleteUser(String id);
}
```

```dart
// infrastructure/data_sources/user/user_api_rest.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class UserApiRest implements IUserApi {
  UserApiRest(String url, http.Client client)
      : assert(
          url.startsWith(RegExp(r'^https?://')),
          'URL must start with "http://" or "https://"',
        ),
        assert(!url.endsWith('/'), 'URL must not end with "/"'),
        _baseUrl = url,
        _client = client;

  final String _baseUrl;
  final http.Client _client;

  @override
  Future<Map<String, dynamic>> getUser(String id) async {
    final response = await _client.get(Uri.parse('$_baseUrl/users/$id'));
    _assertSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client.get(Uri.parse('$_baseUrl/users'));
    _assertSuccess(response);
    return (jsonDecode(response.body) as List).cast();
  }

  @override
  Future<void> updateUser(String id, Map<String, dynamic> body) async {
    final response = await _client.put(
      Uri.parse('$_baseUrl/users/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _assertSuccess(response);
  }

  @override
  Future<void> deleteUser(String id) async {
    final response = await _client.delete(Uri.parse('$_baseUrl/users/$id'));
    _assertSuccess(response);
  }

  void _assertSuccess(http.Response response) {
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) throw const NotFoundException();
    if (response.statusCode >= 400) throw ServerException(response.statusCode);
  }
}
```
