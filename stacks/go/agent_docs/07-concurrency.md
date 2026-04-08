# 07 · Concurrency

Go's goroutines and channels are its most distinctive feature. Used well, they make concurrent code natural and readable. Used carelessly, they produce goroutine leaks, race conditions, and deadlocks that are extremely hard to debug.

The guiding principle: **don't reach for concurrency until you need it.** Sequential code is easier to read, test, and reason about. When you do use concurrency, use the right tool and be explicit about cleanup.

---

## Every Goroutine Needs an Exit Condition

A goroutine that runs forever without a way to be stopped is a leak. In a long-running server, goroutine leaks accumulate and eventually exhaust memory.

The exit condition is almost always context cancellation.

```go
// ✅ Goroutine respects context cancellation
func (w *Worker) Start(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return  // Clean exit when context is cancelled
            case job := <-w.jobs:
                w.process(job)
            }
        }
    }()
}
```

```go
// ❌ Goroutine runs forever with no exit
func (w *Worker) Start() {
    go func() {
        for job := range w.jobs {
            w.process(job)
        }
    }()
}
```

---

## Use `errgroup` for Concurrent Work

`golang.org/x/sync/errgroup` is the standard way to run multiple goroutines and collect their errors. It handles `sync.WaitGroup` and error collection for you.

```go
import "golang.org/x/sync/errgroup"

// ✅ Parallel fan-out with errgroup
func (s *Service) GetDashboard(ctx context.Context, userID string) (*Dashboard, error) {
    g, ctx := errgroup.WithContext(ctx)

    var user *User
    var orders []*Order
    var notifications []*Notification

    g.Go(func() error {
        var err error
        user, err = s.userRepo.FindByID(ctx, userID)
        return err
    })

    g.Go(func() error {
        var err error
        orders, err = s.orderRepo.FindByUserID(ctx, userID)
        return err
    })

    g.Go(func() error {
        var err error
        notifications, err = s.notifRepo.FindUnread(ctx, userID)
        return err
    })

    if err := g.Wait(); err != nil {
        return nil, fmt.Errorf("building dashboard: %w", err)
    }

    return buildDashboard(user, orders, notifications), nil
}
```

When any goroutine returns an error, the context is cancelled, signalling the others to stop early.

---

## Worker Pool for Bounded Concurrency

When processing a large number of items, don't spawn one goroutine per item — that can exhaust resources. Use a worker pool to bound the number of concurrent operations.

```go
// ✅ Worker pool — at most `workers` goroutines running concurrently
func ProcessItems(ctx context.Context, items []Item, workers int) error {
    g, ctx := errgroup.WithContext(ctx)
    ch := make(chan Item)

    // Producer: feed items into the channel
    g.Go(func() error {
        defer close(ch)
        for _, item := range items {
            select {
            case ch <- item:
            case <-ctx.Done():
                return ctx.Err()
            }
        }
        return nil
    })

    // Workers: consume items from the channel
    for range workers {
        g.Go(func() error {
            for item := range ch {
                if err := process(ctx, item); err != nil {
                    return err
                }
            }
            return nil
        })
    }

    return g.Wait()
}
```

---

## Context for Cancellation and Timeouts

Context is the standard mechanism for propagating cancellation and deadlines. Pass it everywhere I/O happens.

```go
// ✅ Wrap external calls with timeouts
func (s *Service) FetchExternalData(ctx context.Context, id string) (*Data, error) {
    ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
    defer cancel()  // Always call cancel to release resources

    return s.externalClient.Fetch(ctx, id)
}
```

**Rules:**
- `context.Context` is always the **first parameter** of any function that does I/O.
- Always `defer cancel()` when you create a context with `WithTimeout` or `WithCancel`.
- Never store a context in a struct — pass it as a parameter at call time.
- `context.Background()` is only for `main()`, `init()`, and tests.

---

## Channels vs Mutexes

Go's motto is "share memory by communicating" — but that doesn't mean always use channels. Use the simpler tool for the job.

| Use channels when... | Use a mutex when... |
|----------------------|---------------------|
| Passing ownership of data between goroutines | Protecting shared state accessed from multiple goroutines |
| Coordinating/signalling between goroutines | Caching or memoizing results |
| Pipeline patterns (producer → consumer) | Updating a counter, map, or struct field |

```go
// ✅ Mutex for protecting a shared cache — simpler than channels here
type Cache struct {
    mu    sync.RWMutex
    store map[string]*User
}

func (c *Cache) Get(key string) (*User, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    u, ok := c.store[key]
    return u, ok
}

func (c *Cache) Set(key string, user *User) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.store[key] = user
}
```

```go
// ✅ Channel for pipeline — ownership transfers through the pipeline
func generateIDs(ctx context.Context) <-chan string {
    out := make(chan string)
    go func() {
        defer close(out)
        for {
            select {
            case out <- newID():
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}
```

---

## Always Run Tests with the Race Detector

The Go race detector catches data races at runtime. Run it in CI and locally when working with concurrent code.

```bash
go test -race ./...
```

---

## Anti-Patterns

### ❌ Naked goroutine with no exit condition
```go
func StartProcessor() {
    go func() {
        for {
            processNextItem()  // Runs forever. Can never be stopped.
        }
    }()
}
```

### ❌ Goroutine-per-request without bounds
```go
for _, item := range millionItems {
    go process(item)  // Spawns 1,000,000 goroutines simultaneously
}
```

### ❌ Ignoring goroutine errors
```go
go func() {
    if err := doSomething(); err != nil {
        // Error silently dropped
    }
}()
```
Use `errgroup` to surface errors from goroutines.

### ❌ Launching goroutines in library code without a way to stop them
```go
// In a constructor — the goroutine leaks when the service is no longer needed
func NewService(repo Repository) *Service {
    s := &Service{repo: repo}
    go s.runBackgroundSync()  // How does the caller stop this?
    return s
}
```
**Fix:** Accept a context, or expose a `Start(ctx context.Context)` / `Stop()` method.

### ❌ Copying a mutex
```go
mu := sync.Mutex{}
mu2 := mu    // ❌ Copying a mutex corrupts its state
```
Always use pointers to mutexes, or embed them in structs and never copy the struct after first use.

### ❌ Using `time.Sleep` for coordination
```go
go doWork()
time.Sleep(100 * time.Millisecond)  // Hoping the goroutine is done by now
checkResult()
```
Use `sync.WaitGroup`, `errgroup`, or channels to coordinate goroutines. `time.Sleep` is a race condition waiting to happen.

---

[← Dependency Injection](./06-dependency-injection.md) | [Index](./README.md) | [Next: Testing →](./08-testing.md)
