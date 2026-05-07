# Flutter — Standards Reference

## Architecture

Clean Architecture with four layers. BLoC/Cubit for state management. `fpdart` for functional error handling.

```
lib/
  features/
    <feature>/
      domain/         ← Entities, Repository interfaces, Validators (pure Dart)
      application/    ← Use Cases — orchestration, TaskEither<Failure, T>
      infrastructure/ ← Repository implementations, Data Sources, DTOs
      presentation/   ← Pages, Views, Blocs, Widgets
        pages/        ← Creates BlocProvider, navigation entry points
        views/        ← BlocBuilder/BlocConsumer, layout
        blocs/        ← Events, States, Bloc class
  shared/             ← Cross-feature: theme, routes, DI, common widgets
```

## Key Patterns

- **BLoC unidirectional flow** — UI → Event → Bloc → State → UI; Blocs never talk to each other directly
- **Use cases in Blocs** — Blocs inject use cases (not repositories); repositories are infrastructure
- **TaskEither for async** — all async operations return `TaskEither<Failure, T>`; call `.run()` to execute
- **Sealed class failures** — domain failures are sealed classes; UI pattern-matches exhaustively
- **Pages create, Views consume** — `BlocProvider` only in Page widgets; Views only read via `context.read/watch`
- **Infrastructure translates exceptions** — data sources catch raw exceptions, map to domain `Failure` types
- **No Flutter in domain** — domain has zero imports from `flutter/` packages

## Layer Responsibilities

### Domain (pure Dart only)

- Entities: readonly classes with immutable fields
- Repository interfaces: abstract classes defining data contracts
- Failures: sealed classes modeling expected error states
- No `flutter/`, no `dart:io`, no external packages

### Application

- Use cases with `execute()` returning `TaskEither<Failure, T>`
- Orchestrates domain repositories; no UI imports

### Infrastructure

- Implements domain repository interfaces
- Data sources: REST APIs, local DB, secure storage
- DTOs: `fromJson()`/`toJson()`, maps to domain entities
- Catches raw exceptions and maps to domain `Failure` types

### Presentation

- Pages: create `BlocProvider`, navigation entry points
- Views: use `BlocBuilder`/`BlocConsumer` to read state, render UI
- Blocs: handle events, call use cases, emit states
- Widgets/Components: pure, receive data as parameters

## BLoC Pattern

```dart
// Bloc
class HabitBloc extends Bloc<HabitEvent, HabitState> {
  final GetHabitsUseCase _getHabits;

  HabitBloc(this._getHabits) : super(HabitInitial()) {
    on<LoadHabits>(_onLoadHabits);
  }

  Future<void> _onLoadHabits(LoadHabits event, Emitter<HabitState> emit) async {
    emit(HabitLoading());
    final result = await _getHabits.execute().run(); // TaskEither.run()
    result.fold(
      (failure) => emit(HabitError(failure)),
      (habits) => emit(HabitLoaded(habits)),
    );
  }
}
```

## Page vs View Pattern

```dart
// Page — creates BlocProvider only, delegates UI to View
class HabitsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HabitBloc(GetIt.I<GetHabitsUseCase>())..add(LoadHabits()),
      child: const HabitsView(),
    );
  }
}

// View — reads BlocProvider, renders UI
class HabitsView extends StatelessWidget {
  const HabitsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitBloc, HabitState>(
      builder: (context, state) {
        if (state is HabitLoading) return const CircularProgressIndicator();
        if (state is HabitError) return ErrorWidget(state.failure.message);
        if (state is HabitLoaded) return HabitList(habits: state.habits);
        return const SizedBox.shrink();
      },
    );
  }
}
```

## TaskEither Error Handling

```dart
// Use case — returns TaskEither
class GetHabitsUseCase {
  final IHabitRepository _repository;
  GetHabitsUseCase(this._repository);

  TaskEither<Failure, List<Habit>> execute() => _repository.getAll();
}

// Infrastructure — catches exceptions, maps to Failure
class HabitRepositoryImpl implements IHabitRepository {
  @override
  TaskEither<Failure, List<Habit>> getAll() => TaskEither.tryCatch(
    () => _dataSource.fetchAll().then((dtos) => dtos.map((d) => d.toEntity()).toList()),
    (error, _) => ServerFailure(error.toString()),
  );
}
```

Never `throw` for expected failures — use `Left(Failure(...))`.

## Task Type → Key Patterns

| Task | Patterns to apply |
|---|---|
| Any UI work | Architecture, folder structure, naming conventions |
| Presentation / UI | Presentation layer rules, Page vs View, BLoC pattern |
| BLoC / State | State management, sealed event/state classes |
| Use Cases | Application layer rules, `TaskEither` pattern |
| Domain model | Domain layer rules, entities, repository interfaces |
| Infrastructure | Data sources, DTOs, repository implementations |

## Red Flags

- Bloc calling a repository directly (should call a use case)
- `throw Exception(...)` for an expected failure (use `Left(Failure(...))`)
- Business logic inside a Widget's `build()` method
- Flutter package imports inside the `domain/` layer
- `TaskEither` without `.run()` — forgetting to execute the lazy computation
- `BlocProvider` in View widgets (belongs in Page only)
- Cross-Bloc dependency via direct reference (use `BlocListener`)

## Verification Checklist

- [ ] `flutter build apk --debug` passes without errors
- [ ] `flutter analyze` passes with no issues
- [ ] `flutter test` passes; all BLoC state transitions covered
- [ ] No `flutter/` package imports in `domain/` layer
- [ ] All async fallible operations return `TaskEither` (not raw `Future<T>`)
- [ ] `BlocProvider` only in Page widgets (not in View or Body)
- [ ] Failures are sealed classes — exhaustive pattern matching in Views
