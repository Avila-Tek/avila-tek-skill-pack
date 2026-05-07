# NestJS — Security Reference (OWASP Top 10)

## A01 · Broken Access Control

Every endpoint must declare its access requirements explicitly. An endpoint with no guard is public by default — that's a vulnerability, not a default.

```typescript
// ✅ Controller-level auth guard + endpoint-level permission
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, PermissionsGuard)
@Controller('quotes')
export class QuoteController {

  @Post()
  @Permissions('quote:write')
  async create(@Body() body: TCreateQuoteInput) { ... }

  @Get()
  @Permissions('quote:read')
  async findAll() { ... }

  @Get('health')
  @Public()               // explicit opt-out — requires conscious decision
  async health() { ... }
}
```

**Rule:** endpoint without `@Public()` and without `@Permissions()` = unprotected. Any authenticated user can call it.

Resource ownership — always verify the authenticated user owns the resource:

```typescript
async update(id: number, userId: string, dto: UpdateDto) {
  const record = await this.repo.findById(id);
  if (!record) throw new NotFoundException();
  if (record.ownerId !== userId) throw new ForbiddenException(); // ← never skip this
  return this.repo.update(id, dto);
}
```

## A02 · Cryptographic Failures

Sensitive data must never travel or rest in plaintext.

```typescript
// ✅ Passwords — bcrypt with 12+ rounds
import * as bcrypt from 'bcrypt';
const hash = await bcrypt.hash(plaintext, 12);
const valid = await bcrypt.compare(plaintext, hash);

// ❌ Never store or log raw tokens, passwords, or PII
logger.log(`User logged in: ${user.email}`);    // ✅ OK
logger.log(`Token: ${token}`);                  // ❌ Never
logger.log(`Password: ${password}`);            // ❌ Never
```

Config — all secrets from `ConfigService`, never hardcoded:

```typescript
// ✅
const secret = this.configService.getOrThrow<string>('JWT_SECRET');

// ❌
const secret = 'my-super-secret-key';
```

## A03 · Injection

**SQL/NoSQL injection:** never concatenate user input into queries. Use Drizzle's parameterized API:

```typescript
// ✅ Drizzle — parameterized
const result = await db.select().from(users).where(eq(users.email, email));

// ❌ Raw string concatenation — never do this
const result = await db.execute(`SELECT * FROM users WHERE email = '${email}'`);
```

**Command injection:** never pass user input to `exec`, `spawn`, or `eval`.

## A04 · Insecure Design

Validate all inputs at the HTTP boundary before they reach domain or application logic. Use `parseOrThrow` on every `@Param()` and `@Body()` — the global `ZodValidationPipe` doesn't validate TypeScript `type`/`interface` shapes (erased at runtime):

```typescript
@Post()
async create(@Body() body: TCreateOfficeInput): Promise<TOffice> {
  const parsed = parseOrThrow(createOfficeInput, body); // throws 400 on invalid input
  return this.createUseCase.execute(parsed);
}

@Get(':id')
async findOne(@Param() params: { id: string }) {
  const { id } = parseOrThrow(officeIdParamsSchema, params);
  // ...
}
```

Zod schema rules:

```typescript
// ✅ trim before min(1) — prevents "   " passing validation
name: z.string().trim().min(1, 'Name is required'),
// ❌ "   " passes min(1) but collapses to "" after trimming
name: z.string().min(1, 'Name is required'),
```

## A05 · Security Misconfiguration

Security headers via Helmet. CORS restricted to known origins:

```typescript
// main.ts
import helmet from 'helmet';

app.use(helmet());
app.enableCors({
  origin: configService.getOrThrow('ALLOWED_ORIGINS').split(','),
  credentials: true,
});
```

Rate limiting on auth endpoints:

```typescript
@Controller('auth')
@Throttle({ default: { limit: 10, ttl: 60000 } }) // 10 requests / minute
export class AuthController { ... }
```

## A06 · Vulnerable and Outdated Components

```bash
npm audit             # before every release
npm audit --fix       # auto-fix where safe
```

Fix critical/high vulnerabilities that are reachable at runtime before merging.

## A07 · Identification and Authentication Failures

- JWT access tokens: short expiry (15 min max)
- Refresh tokens: stored as BCrypt hash, never raw; rotate on every use
- `@ApiBearerAuth()` + `JwtAuthGuard` on every protected controller
- Rate-limit login and password reset endpoints (see A05)

## A08 · Software and Data Integrity Failures

Never deserialize untrusted data without schema validation. All `@Body()` must go through `parseOrThrow`. Never use `JSON.parse` on external data without a Zod schema.

## A09 · Security Logging and Monitoring Failures

Log once at the boundary, not at every propagation level. Never log sensitive data:

```typescript
// ✅ Log the error, not the credentials
@ExceptionHandler(DomainException.class)
catch (e: DomainException) {
  this.logger.error('Domain error', { code: e.code, path: request.url });
  // ❌ never: this.logger.error('Error', { body: request.body })
}
```

## A10 · Server-Side Request Forgery (SSRF)

When making HTTP calls to URLs derived from user input, validate the target:

```typescript
// ✅ Allowlist known domains before fetching
const ALLOWED_HOSTS = ['api.trusted.com', 'hooks.trusted.com'];
const url = new URL(userProvidedUrl);
if (!ALLOWED_HOSTS.includes(url.hostname)) throw new BadRequestException('Invalid URL');
```

## Verification Checklist

- [ ] Every controller has `@ApiBearerAuth()` + `@UseGuards(JwtAuthGuard, PermissionsGuard)` or is explicitly `@Public()`
- [ ] Every write endpoint has `@Permissions('<module>:write')`
- [ ] `parseOrThrow` on all `@Param()` and `@Body()`
- [ ] Zod schemas use `.trim().min(1)`, not `.min(1)` alone
- [ ] Passwords hashed with bcrypt (rounds ≥ 12)
- [ ] No secrets hardcoded — all via `ConfigService`
- [ ] Helmet + CORS + rate limiting configured in `main.ts`
- [ ] `npm audit` clean before release
- [ ] No sensitive data in logs
