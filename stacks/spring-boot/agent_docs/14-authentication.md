# 14 · Authentication

Spring Security in Spring Boot 3.x is configured through a `SecurityFilterChain` bean. The `WebSecurityConfigurerAdapter` class was deprecated in Spring Security 5.7 and removed in 6.0 — it must not be used. The `SecurityFilterChain` approach is composable, testable, and aligns with the `@Bean` factory model used everywhere else in Hexagonal Architecture. Security configuration is infrastructure; it lives in `infrastructure/security/` and has no visibility into domain logic.

JWT authentication follows a well-defined flow: the client authenticates with credentials, receives a short-lived access token and a longer-lived refresh token, includes the access token in every subsequent request, and exchanges the refresh token for a new pair before the access token expires. The server never stores access tokens — it only stores refresh tokens (hashed, in the database) to support revocation. This stateless model scales horizontally without session affinity.

---

## Architecture: JWT Auth Flow

```
Client                          Server
  │                               │
  │  POST /auth/login             │
  │  { email, password }          │
  ├──────────────────────────────►│
  │                               │  AuthService.login()
  │                               │  → verify credentials
  │                               │  → generate access token (15m)
  │                               │  → generate refresh token (7d)
  │                               │  → store hashed refresh token in DB
  │  200 { accessToken,           │
  │         refreshToken }        │
  │◄──────────────────────────────┤
  │                               │
  │  GET /api/v1/users/me         │
  │  Authorization: Bearer <AT>   │
  ├──────────────────────────────►│
  │                               │  JwtAuthenticationFilter
  │                               │  → validate signature + expiry
  │                               │  → populate SecurityContext
  │  200 { user data }            │
  │◄──────────────────────────────┤
  │                               │
  │  POST /auth/refresh           │
  │  { refreshToken }             │
  ├──────────────────────────────►│
  │                               │  AuthService.refresh()
  │                               │  → look up hashed token in DB
  │                               │  → validate, rotate (invalidate old, issue new)
  │  200 { accessToken,           │
  │         newRefreshToken }     │
  │◄──────────────────────────────┤
```

---

## `SecurityFilterChain` Bean

```java
// ✅ Good — SecurityFilterChain bean; no WebSecurityConfigurerAdapter
package com.avilatek.shared.infrastructure.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true)  // enables @PreAuthorize
public class SecurityConfiguration {

    private final JwtAuthenticationFilter jwtAuthFilter;
    private final JwtAuthenticationEntryPoint entryPoint;

    public SecurityConfiguration(JwtAuthenticationFilter jwtAuthFilter,
                                  JwtAuthenticationEntryPoint entryPoint) {
        this.jwtAuthFilter = jwtAuthFilter;
        this.entryPoint = entryPoint;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())               // stateless JWT — no CSRF needed
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(ex -> ex
                .authenticationEntryPoint(entryPoint))  // returns 401 ProblemDetail
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/auth/**").permitAll()
                .requestMatchers("/actuator/health", "/actuator/prometheus").permitAll()
                .requestMatchers(HttpMethod.GET, "/api/v1/public/**").permitAll()
                .anyRequest().authenticated())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder(12);
    }

    @Bean
    public AuthenticationManager authenticationManager(
            AuthenticationConfiguration authenticationConfiguration) throws Exception {
        return authenticationConfiguration.getAuthenticationManager();
    }
}
```

---

## JWT Authentication Filter

```java
// ✅ Good — OncePerRequestFilter validates JWT and populates SecurityContext
package com.avilatek.shared.infrastructure.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserDetailsService userDetailsService;

    public JwtAuthenticationFilter(JwtService jwtService, UserDetailsService userDetailsService) {
        this.jwtService = jwtService;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7);

        try {
            String subject = jwtService.extractSubject(token);

            if (subject != null && SecurityContextHolder.getContext().getAuthentication() == null) {
                UserDetails userDetails = userDetailsService.loadUserByUsername(subject);

                if (jwtService.isTokenValid(token, userDetails)) {
                    UsernamePasswordAuthenticationToken auth =
                        new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
                    auth.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                    SecurityContextHolder.getContext().setAuthentication(auth);
                }
            }
        } catch (Exception ex) {
            // Invalid token — do not set authentication; let the request proceed unauthenticated
            // The security config will reject it at the authorization check
            logger.debug("JWT validation failed: " + ex.getMessage());
        }

        filterChain.doFilter(request, response);
    }
}
```

---

## JWT Service

```java
// ✅ Good — JWT service using JJWT 0.12.x API
package com.avilatek.shared.infrastructure.security;

import com.avilatek.shared.infrastructure.config.JwtProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

    private final JwtProperties jwtProperties;

    public JwtService(JwtProperties jwtProperties) {
        this.jwtProperties = jwtProperties;
    }

    public String generateAccessToken(UserDetails userDetails) {
        return Jwts.builder()
            .subject(userDetails.getUsername())
            .issuedAt(Date.from(Instant.now()))
            .expiration(Date.from(Instant.now().plus(jwtProperties.accessTokenExpiry())))
            .signWith(signingKey())
            .compact();
    }

    public String extractSubject(String token) {
        return extractClaims(token).getSubject();
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        String subject = extractSubject(token);
        return subject.equals(userDetails.getUsername()) && !isTokenExpired(token);
    }

    private boolean isTokenExpired(String token) {
        return extractClaims(token).getExpiration().before(new Date());
    }

    private Claims extractClaims(String token) {
        return Jwts.parser()
            .verifyWith(signingKey())
            .build()
            .parseSignedClaims(token)
            .getPayload();
    }

    private SecretKey signingKey() {
        return Keys.hmacShaKeyFor(jwtProperties.secret().getBytes());
    }
}
```

---

## `UserDetailsService` Implementation

```java
// ✅ Good — UserDetailsService loads user from domain repository
package com.avilatek.users.infrastructure.security;

import com.avilatek.users.domain.Email;
import com.avilatek.users.domain.UserRepository;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    public UserDetailsServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String email) throws UsernameNotFoundException {
        return userRepository.findByEmail(new Email(email))
            .map(user -> User.builder()
                .username(user.email().value())
                .password("")  // password not stored on the domain entity; auth service handles it
                .authorities(List.of(new SimpleGrantedAuthority("ROLE_USER")))
                .accountLocked(user.isSuspended())
                .build())
            .orElseThrow(() -> new UsernameNotFoundException("User not found: " + email));
    }
}
```

---

## Role-Based Access Control with `@PreAuthorize`

```java
// ✅ Good — method-level security; @EnableMethodSecurity required in SecurityConfiguration
package com.avilatek.users.presentation;

import org.springframework.security.access.prepost.PreAuthorize;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public List<UserResponse> listAll() {
        return userService.listAll();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN') or #id == authentication.name")
    public UserResponse getById(@PathVariable UUID id) {
        return userService.getUser(id.toString());
    }

    @PatchMapping("/{id}/suspend")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void suspend(@PathVariable UUID id) {
        userService.suspendUser(id.toString());
    }
}
```

---

## Refresh Token Rotation

Refresh token rotation invalidates the old token every time a new token pair is issued. This limits the window of exposure if a refresh token is stolen.

```java
// ✅ Good — refresh token stored as a hash, rotated on every use
package com.avilatek.shared.infrastructure.security;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class RefreshTokenService {

    private final RefreshTokenRepository tokenRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    public RefreshTokenService(RefreshTokenRepository tokenRepository,
                                JwtService jwtService,
                                PasswordEncoder passwordEncoder) {
        this.tokenRepository = tokenRepository;
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
    }

    public TokenPair rotate(String rawRefreshToken) {
        String tokenHash = passwordEncoder.encode(rawRefreshToken);
        RefreshTokenEntity stored = tokenRepository.findByTokenHash(tokenHash)
            .orElseThrow(() -> new InvalidRefreshTokenException("Refresh token not found or already used"));

        if (stored.isExpired()) {
            tokenRepository.delete(stored);
            throw new InvalidRefreshTokenException("Refresh token has expired");
        }

        tokenRepository.delete(stored);  // invalidate old token

        String newRefreshToken = generateSecureToken();
        tokenRepository.save(new RefreshTokenEntity(
            stored.userId(),
            passwordEncoder.encode(newRefreshToken),
            Instant.now().plus(jwtProperties.refreshTokenExpiry())
        ));

        String newAccessToken = jwtService.generateAccessTokenForUserId(stored.userId());
        return new TokenPair(newAccessToken, newRefreshToken);
    }

    private String generateSecureToken() {
        byte[] bytes = new byte[64];
        new java.security.SecureRandom().nextBytes(bytes);
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
```

---

## Anti-Patterns

### ❌ Using `WebSecurityConfigurerAdapter`
```java
// ❌ Bad — removed in Spring Security 6 / Spring Boot 3
@Configuration
public class SecurityConfig extends WebSecurityConfigurerAdapter {
    @Override
    protected void configure(HttpSecurity http) throws Exception { ... }
}
```
Use `SecurityFilterChain` as a `@Bean` instead. It is composable and does not require inheritance.

### ❌ Storing raw refresh tokens in the database
```java
// ❌ Bad — raw token in DB; if the DB is breached, all sessions are compromised
refreshTokenRepository.save(new RefreshToken(userId, rawToken, expiry));
```
Store a BCrypt or SHA-256 hash of the refresh token. The raw token is only ever held in memory during the request.

### ❌ Logging JWT tokens
```java
log.debug("Generated JWT: {}", token);  // ❌ token in logs; logs are often aggregated
```
Tokens are credentials. Never log them.

### ❌ Not expiring access tokens
```java
// ❌ Bad — no expiry set on the JWT
Jwts.builder()
    .subject(email)
    // missing .expiration(...)
    .signWith(key)
    .compact();
```
Access tokens without expiry are permanent credentials. If one leaks, there is no recovery path. Set the expiry to 15 minutes or less.

---

[← Tooling](./13-tooling.md) | [Index](./README.md)
