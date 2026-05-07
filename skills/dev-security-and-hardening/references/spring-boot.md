# Spring Boot — Security Reference (OWASP Top 10)

## A01 · Broken Access Control

Use `SecurityFilterChain` + `@PreAuthorize` for access control. `WebSecurityConfigurerAdapter` was removed in Spring Boot 3 — never use it:

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)  // enables @PreAuthorize
public class SecurityConfiguration {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())   // stateless JWT — no CSRF session
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated())   // ← deny-by-default
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
```

Method-level RBAC with `@PreAuthorize`:

```java
@GetMapping
@PreAuthorize("hasRole('ADMIN')")
public List<UserResponse> listAll() { ... }

@GetMapping("/{id}")
@PreAuthorize("hasRole('ADMIN') or #id == authentication.name")  // owner or admin
public UserResponse getById(@PathVariable UUID id) { ... }
```

Resource ownership — always check the authenticated user owns the resource:

```java
public OrderResponse updateOrder(String orderId, String callerId, UpdateOrderDto dto) {
    Order order = orderRepository.findById(orderId)
        .orElseThrow(() -> new OrderNotFoundException(orderId));
    if (!order.ownerId().equals(callerId)) {
        throw new AccessDeniedException("Not the owner of this order");
    }
    // proceed
}
```

## A02 · Cryptographic Failures

Passwords hashed with BCrypt (strength ≥ 12):

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

JWT: short-lived access token (≤ 15 min), refresh token stored as hash (never raw):

```java
// ✅ Access token — short expiry
Jwts.builder()
    .subject(userDetails.getUsername())
    .expiration(Date.from(Instant.now().plus(jwtProperties.accessTokenExpiry())))
    .signWith(signingKey())
    .compact();

// ✅ Refresh token stored as BCrypt hash in DB
String rawToken = generateSecureToken();
tokenRepository.save(new RefreshTokenEntity(userId, passwordEncoder.encode(rawToken), expiry));
// ❌ Never store raw refresh token: tokenRepository.save(new RefreshTokenEntity(userId, rawToken, expiry));
```

Never log JWTs, passwords, or raw tokens:

```java
// ❌
log.debug("Generated JWT: {}", token);  // token in logs — never
log.debug("Password: {}", rawPassword); // never
```

## A03 · Injection

**SQL injection:** JPA/Hibernate parameterizes all queries automatically. Never use native queries with string concatenation:

```java
// ✅ Spring Data — parameterized
Optional<UserEntity> findByEmail(String email);

// ✅ JPQL — parameterized
@Query("SELECT u FROM UserEntity u WHERE u.email = :email")
Optional<UserEntity> findByEmail(@Param("email") String email);

// ❌ Never — SQL injection via string concatenation
@Query(value = "SELECT * FROM users WHERE email = '" + email + "'", nativeQuery = true)
```

## A04 · Insecure Design

Validate at the HTTP boundary with Bean Validation (`@Valid`) before data reaches the service:

```java
// Request DTO with validation constraints
public record CreateUserRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(min = 8, max = 100) String password,
    @NotBlank @Size(max = 100) String name
) {}

// Controller — @Valid triggers validation; MethodArgumentNotValidException → 400
@PostMapping
@ResponseStatus(HttpStatus.CREATED)
public UserResponse create(@Valid @RequestBody CreateUserRequest request) {
    return userService.createUser(request.email(), request.name(), request.password());
}
```

Domain validation in constructors (invariants, not HTTP concerns):

```java
public record Email(String value) {
    public Email {
        if (value == null || !value.contains("@"))
            throw new InvalidEmailException("Invalid email: " + value);
    }
}
```

## A05 · Security Misconfiguration

Security headers — configure in `SecurityFilterChain` or via Helmet-equivalent response headers:

```java
http.headers(headers -> headers
    .frameOptions(frame -> frame.deny())
    .contentTypeOptions(Customizer.withDefaults())
    .httpStrictTransportSecurity(hsts -> hsts
        .maxAgeInSeconds(31536000)
        .includeSubDomains(true))
);
```

CORS restricted to known origins:

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOrigins(List.of(allowedOrigins.split(",")));  // from config
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE"));
    config.setAllowCredentials(true);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

Rate limiting on auth endpoints — use a filter or Bucket4j:

```java
// Auth endpoints should be rate-limited to prevent brute force
@Component
public class RateLimitingFilter extends OncePerRequestFilter {
    // Apply stricter limits on /auth/login and /auth/forgot-password
}
```

## A06 · Vulnerable and Outdated Components

```bash
./gradlew dependencyCheckAnalyze    # OWASP dependency check plugin
./mvnw org.owasp:dependency-check-maven:check
```

Run in CI. Fix critical/high CVEs before release.

## A07 · Identification and Authentication Failures

JWT filter — validate signature, expiry, and populate `SecurityContext`:

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String authHeader = req.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            chain.doFilter(req, res);
            return;
        }
        try {
            String token = authHeader.substring(7);
            String subject = jwtService.extractSubject(token);
            if (subject != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(subject);
                if (jwtService.isTokenValid(token, userDetails)) {
                    var auth = new UsernamePasswordAuthenticationToken(
                        userDetails, null, userDetails.getAuthorities());
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                }
            }
        } catch (Exception ex) {
            // Invalid token — proceed unauthenticated; security config rejects at authorization
            logger.debug("JWT validation failed: " + ex.getMessage());
        }
        chain.doFilter(req, res);
    }
}
```

## A08 · Software and Data Integrity Failures

Validate responses from external HTTP clients before use:

```java
// ✅ Validate external response shape
ExternalUserDto dto = restTemplate.getForObject(url, ExternalUserDto.class);
if (dto == null || dto.id() == null) {
    throw new ExternalServiceException("Unexpected response from user service");
}
```

## A09 · Security Logging and Monitoring Failures

Log at the `@ControllerAdvice` boundary, not at every layer. Never log credentials:

```java
@ExceptionHandler(DomainException.class)
public ProblemDetail handleDomain(DomainException ex, HttpServletRequest req) {
    log.error("Domain error: {} at {}", ex.getMessage(), req.getRequestURI());
    // ❌ Never log: req.getParameter("password"), request body contents
    return ProblemDetail.forStatusAndDetail(HttpStatus.valueOf(ex.getStatus()), ex.getMessage());
}
```

## A10 · Server-Side Request Forgery (SSRF)

Validate URLs from user input before outbound requests:

```java
private static final Set<String> ALLOWED_HOSTS = Set.of("api.trusted.com", "webhooks.trusted.com");

public void validateWebhookUrl(String rawUrl) {
    try {
        URI uri = new URI(rawUrl);
        if (!"https".equals(uri.getScheme())) throw new IllegalArgumentException("Only HTTPS allowed");
        if (!ALLOWED_HOSTS.contains(uri.getHost())) throw new IllegalArgumentException("Host not allowed");
    } catch (URISyntaxException e) {
        throw new IllegalArgumentException("Invalid URL");
    }
}
```

## Verification Checklist

- [ ] `SecurityFilterChain` bean — no `WebSecurityConfigurerAdapter`
- [ ] `anyRequest().authenticated()` — deny by default
- [ ] `@PreAuthorize` on every sensitive endpoint
- [ ] Resource ownership verified before mutation
- [ ] `BCryptPasswordEncoder(12)` in `@Bean`
- [ ] JWT access token expiry ≤ 15 min
- [ ] Refresh tokens stored as BCrypt hash — never raw
- [ ] `@Valid` on all `@RequestBody` DTOs
- [ ] Bean Validation constraints on all request records
- [ ] CORS restricted to known origins from config
- [ ] Security headers configured
- [ ] No JWT/passwords in logs
- [ ] OWASP dependency check in CI
