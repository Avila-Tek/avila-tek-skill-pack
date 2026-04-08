# Infrastructure Layer

## Purpose

The infrastructure layer is the **outer shell** of the application. It connects the domain to the external world: REST APIs, GraphQL endpoints, local databases, device storage, analytics services, and so on.

It fulfills the contracts (repository interfaces) defined in the domain without the domain ever knowing the implementation details.

## Rules

- Only depends on the **domain layer** (entities, errors, repository interfaces).
- Must **not** depend on the application or presentation layers.
- All exceptions from external sources **must** be caught here and mapped to domain errors.
- **No business logic** — infrastructure code moves data; it does not make decisions.
- DTOs **must not** extend domain entities. See [DTOs](./dtos.md).

## Components

| Component | Description |
|---|---|
| Data Sources | Classes that communicate with external systems (APIs, databases, etc.) |
| DTOs | Data Transfer Objects for serialization/deserialization |
| Repositories | Concrete implementations of the domain's repository interfaces |

## Folder Structure

```
infrastructure/
├── data_sources/
│   ├── user/
│   │   ├── i_user_api.dart          # Data source interface
│   │   └── user_api_rest.dart       # REST implementation
│   └── orders/
│       ├── i_orders_api.dart
│       ├── orders_api_rest.dart
│       └── orders_api_mock.dart     # Mock for testing
├── dtos/
│   ├── enums/
│   │   ├── user_status_dto.dart
│   │   └── order_status_dto.dart
│   ├── user_dto.dart
│   └── order_dto.dart
└── repositories/
    ├── user_repository.dart
    └── order_repository.dart
```

## Detailed Docs

- [Data Sources](./data-sources.md)
- [DTOs](./dtos.md)
- [Repository Implementations](./repositories.md)
