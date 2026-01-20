# REST API Plan

This document defines a comprehensive REST API contract for **Flashcards AI (MVP)** based on:
- DB schema in `.ai/db-plan.md` and the applied Supabase migration `supabase/migrations/20260120120000_create_flashcards_mvp_schema.sql`
- Product requirements in `.ai/prd.md`
- Tech stack: **Astro 5 + TypeScript 5 + React 19 + Supabase + OpenRouter**

> **Important implementation note (repo reality):** the migration enables **Row Level Security (RLS)** and defines policies for all tables. The API plan below assumes **Supabase Auth** is the source of identity and DB access is performed in a way that satisfies RLS (i.e., queries are executed with the authenticated user JWT), except for explicitly admin-only operations (e.g. account deletion) which can use the **service role** key.

---

## 1. Zasoby

- **Auth / Session** (Supabase Auth; no `public.users` table)
  - Identity is `auth.users`
- **Decks** → `public.decks`
- **Cards** → `public.cards`
- **AI Generations (metrics)** → `public.ai_generations`
- **AI Suggestions (final state metrics)** → `public.ai_suggestions`
- **(Optional) Metrics views** (not required for MVP)

### Entity relationships (DB-driven)

- `auth.users (1) -> (N) public.decks` via `decks.user_id`
- `public.decks (1) -> (N) public.cards` via `cards.deck_id` (CASCADE on delete)
- `auth.users (1) -> (N) public.ai_generations` via `ai_generations.user_id`
- `public.decks (0..1) <- (N) public.ai_generations` via `ai_generations.deck_id` (SET NULL on deck delete)
- `public.ai_generations (1) -> (N) public.ai_suggestions` via `ai_suggestions.generation_id` (CASCADE on delete)

---

## 2. Punkty końcowe

### 2.1 Conventions (applies to all endpoints)

- **Base path**: `/api`
- **Content type**: `application/json; charset=utf-8`
- **Auth**: `Authorization: Bearer <access_token>` (or cookie-based session, but server must forward JWT to Supabase to satisfy RLS).
- **Response envelope**:

```json
{
  "data": {},
  "meta": {
    "requestId": "uuid-or-short-id"
  }
}
```

- **Error envelope**:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": {
      "fieldErrors": {
        "name": ["Required"]
      }
    }
  },
  "meta": {
    "requestId": "uuid-or-short-id"
  }
}
```

- **Pagination** (cursor-based, recommended):
  - Query params: `limit` (default 20, max 100), `cursor` (opaque string)
  - Response: `meta.nextCursor` if more results exist

```json
{
  "data": [/* items */],
  "meta": { "nextCursor": "opaque", "requestId": "..." }
}
```

- **Sorting**:
  - Query param: `sort` (enumerated per endpoint), e.g. `created_at:desc`
- **Idempotency** (recommended for mutating endpoints that may be retried):
  - Header: `Idempotency-Key: <uuid>`
  - Server stores result for a short TTL per user+key (implementation detail).

---

### 2.2 Auth & account endpoints

> PRD requires: user can log in while unverified, can resend verification email, but **all product actions are blocked until email verification**.

#### POST `/api/auth/sign-up`
- **Description**: Create a new account (email + password) and send verification email.
- **Auth**: none
- **Request JSON**

```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!",
  "emailRedirectTo": "https://app.example.com/auth/callback"
}
```

- **Response JSON (201)**

```json
{
  "data": {
    "user": { "id": "uuid", "email": "user@example.com", "emailVerified": false }
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `400 VALIDATION_ERROR` (bad email/password)
  - `409 EMAIL_ALREADY_REGISTERED`
  - `429 RATE_LIMITED`
  - `500 INTERNAL_ERROR`

#### POST `/api/auth/sign-in`
- **Description**: Sign in with email + password.
- **Auth**: none
- **Request JSON**

```json
{ "email": "user@example.com", "password": "StrongPassword123!" }
```

- **Response JSON (200)**

```json
{
  "data": {
    "session": { "accessToken": "jwt", "expiresAt": "iso" },
    "user": { "id": "uuid", "email": "user@example.com", "emailVerified": false }
  },
  "meta": { "requestId": "..." }
}
```

> If using HTTP-only cookies instead of returning `accessToken`, return `{ session: null }` and set cookies. The API contract can support either, but **server-to-DB must have the user JWT** for RLS.

- **Errors**
  - `400 VALIDATION_ERROR`
  - `401 INVALID_CREDENTIALS`
  - `429 RATE_LIMITED`

#### POST `/api/auth/sign-out`
- **Description**: Sign out current user.
- **Auth**: required
- **Request JSON**: none
- **Response JSON (200)**

```json
{ "data": { "signedOut": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `401 UNAUTHENTICATED`

#### GET `/api/me`
- **Description**: Return current user and verification status (used by UI to block/allow actions).
- **Auth**: required
- **Response JSON (200)**

```json
{
  "data": {
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "emailVerified": true
    }
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `401 UNAUTHENTICATED`

#### POST `/api/auth/resend-verification`
- **Description**: Resend verification email (allowed for unverified users).
- **Auth**: optional (can be either logged-in resend, or email-based resend)
- **Request JSON**

```json
{
  "email": "user@example.com",
  "emailRedirectTo": "https://app.example.com/auth/callback"
}
```

- **Response JSON (200)**

```json
{ "data": { "sent": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `400 VALIDATION_ERROR`
  - `429 RATE_LIMITED`

#### POST `/api/auth/change-password`
- **Description**: Change password for verified users.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{
  "currentPassword": "OldPassword123!",
  "newPassword": "NewPassword123!"
}
```

- **Response JSON (200)**

```json
{ "data": { "changed": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`
  - `401 INVALID_CREDENTIALS` (if current password reauth fails)
  - `400 VALIDATION_ERROR` (weak password)

#### DELETE `/api/auth/account`
- **Description**: Delete the authenticated user account and all owned data (MVP: decks/cards cascade).
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{ "password": "StrongPassword123!" }
```

- **Response JSON (200)**

```json
{ "data": { "deleted": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`
  - `401 INVALID_CREDENTIALS` (reauth)
  - `500 INTERNAL_ERROR`

> **Implementation detail**: account deletion typically requires Supabase Admin API (service role). Do **not** use service role for normal CRUD; use it only where necessary and always tie operations to the authenticated user id.

---

### 2.3 Decks

#### GET `/api/decks`
- **Description**: List decks owned by the current user, including computed card counts.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Query params**
  - `limit` (int, default 20, max 100)
  - `cursor` (string, optional)
  - `sort` = `created_at:desc` | `created_at:asc` | `name:asc` | `name:desc`
  - `q` (string, optional) – search by name (case-insensitive)
- **Response JSON (200)**

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Phrasal verbs",
      "description": "Optional",
      "createdAt": "iso",
      "cardCount": 42
    }
  ],
  "meta": { "nextCursor": "opaque-or-null", "requestId": "..." }
}
```

- **Errors**
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### POST `/api/decks`
- **Description**: Create a deck.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{
  "name": "Phrasal verbs",
  "description": "Optional"
}
```

- **Response JSON (201)**

```json
{
  "data": {
    "id": "uuid",
    "name": "Phrasal verbs",
    "description": "Optional",
    "createdAt": "iso"
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `400 VALIDATION_ERROR` (blank name)
  - `409 DECK_NAME_NOT_UNIQUE` (unique per user, case-insensitive + trim)
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### GET `/api/decks/{deckId}`
- **Description**: Fetch a single deck and summary.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Response JSON (200)**

```json
{
  "data": {
    "id": "uuid",
    "name": "Phrasal verbs",
    "description": "Optional",
    "createdAt": "iso",
    "cardCount": 42
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`
  - `404 NOT_FOUND` (not owned or missing)

#### PATCH `/api/decks/{deckId}`
- **Description**: Update deck name/description.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{
  "name": "New name",
  "description": "New description"
}
```

- **Response JSON (200)**: same shape as GET `/api/decks/{deckId}`
- **Errors**
  - `400 VALIDATION_ERROR`
  - `409 DECK_NAME_NOT_UNIQUE`
  - `404 NOT_FOUND`
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### DELETE `/api/decks/{deckId}`
- **Description**: Delete a deck; DB cascades delete its cards. AI metrics keep generations but `deck_id` becomes NULL (SET NULL).
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Response JSON (200)**

```json
{ "data": { "deleted": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `404 NOT_FOUND`
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

---

### 2.4 Cards

#### GET `/api/decks/{deckId}/cards`
- **Description**: List cards in a deck.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Query params**
  - `limit` (default 50, max 100)
  - `cursor`
  - `sort` = `created_at:desc` | `created_at:asc`
- **Response JSON (200)**

```json
{
  "data": [
    {
      "id": "uuid",
      "deckId": "uuid",
      "front": "to give up",
      "back": "to stop trying",
      "source": "manual",
      "aiGenerationId": null,
      "createdAt": "iso"
    }
  ],
  "meta": { "nextCursor": "opaque-or-null", "requestId": "..." }
}
```

- **Errors**
  - `404 NOT_FOUND` (deck not owned/missing)
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### POST `/api/decks/{deckId}/cards`
- **Description**: Create a manual card in a deck.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{
  "front": "to give up",
  "back": "to stop trying"
}
```

- **Response JSON (201)**

```json
{
  "data": {
    "id": "uuid",
    "deckId": "uuid",
    "front": "to give up",
    "back": "to stop trying",
    "source": "manual",
    "aiGenerationId": null,
    "createdAt": "iso"
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `400 VALIDATION_ERROR`
  - `404 NOT_FOUND` (deck not owned/missing)
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### PATCH `/api/cards/{cardId}`
- **Description**: Update a card front/back.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Request JSON**

```json
{
  "front": "to give up",
  "back": "to stop doing something because it is too difficult"
}
```

- **Response JSON (200)**: same shape as card in list
- **Errors**
  - `400 VALIDATION_ERROR`
  - `404 NOT_FOUND` (card not owned/missing)
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

#### DELETE `/api/cards/{cardId}`
- **Description**: Delete a card.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Response JSON (200)**

```json
{ "data": { "deleted": true }, "meta": { "requestId": "..." } }
```

- **Errors**
  - `404 NOT_FOUND`
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

---

### 2.5 AI generation flow (OpenRouter + metrics)

> DB stores **metrics only**: `ai_generations` + `ai_suggestions.final_state`. It intentionally does **not** store input text nor proposed/edited front/back. The API returns suggestions to the client, and on commit the client sends final decisions (and final content for accepted cards).

#### POST `/api/ai/generations`
- **Description**: Generate flashcard suggestions from pasted text.
- **Auth**: required
- **Preconditions**
  - `emailVerified = true`
  - input text: non-empty, max 10,000 chars
- **Request JSON**

```json
{
  "text": "Long English text pasted by user (<= 10000 chars).",
  "deckId": "uuid-or-null"
}
```

- **Response JSON (201)**

```json
{
  "data": {
    "generation": {
      "id": "uuid",
      "deckId": null,
      "createdAt": "iso",
      "committedAt": null
    },
    "suggestions": [
      { "index": 1, "front": "word/phrase", "back": "definition" }
    ]
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `400 VALIDATION_ERROR` (empty/too long text)
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`
  - `502 AI_PROVIDER_ERROR` (OpenRouter failure)
  - `429 RATE_LIMITED` (anti-abuse, cost control)

#### POST `/api/ai/generations/{generationId}/commit`
- **Description**: Finalize review: store final states (KPI) and create cards for accepted suggestions, then mark generation as committed.
- **Auth**: required
- **Preconditions**
  - `emailVerified = true`
  - generation must be owned by user
  - generation must not be committed yet
  - `deckId` required
  - at least one suggestion must be accepted
- **Request JSON**

```json
{
  "deckId": "uuid",
  "decisions": [
    { "index": 1, "finalState": "accepted_unchanged", "front": "x", "back": "y" },
    { "index": 2, "finalState": "accepted_edited", "front": "edited front", "back": "edited back" },
    { "index": 3, "finalState": "removed" }
  ]
}
```

- **Response JSON (200)**

```json
{
  "data": {
    "generation": {
      "id": "uuid",
      "deckId": "uuid",
      "createdAt": "iso",
      "committedAt": "iso"
    },
    "createdCards": [
      { "id": "uuid", "deckId": "uuid" }
    ],
    "counts": {
      "acceptedUnchanged": 1,
      "acceptedEdited": 1,
      "removed": 1,
      "savedCards": 2
    }
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `400 VALIDATION_ERROR`
    - duplicate indices
    - index outside allowed range
    - missing `front/back` for accepted states
    - front/back too long or blank
    - no accepted suggestions
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`
  - `404 NOT_FOUND` (generation not owned/missing OR deck not owned/missing)
  - `409 GENERATION_ALREADY_COMMITTED`
  - `500 INTERNAL_ERROR`

> **Why commit is a separate endpoint**: PRD requires “save only after final acceptance” and metrics require final states. This design avoids partial writes and enables an atomic transaction: insert `ai_suggestions`, insert accepted `cards`, update `ai_generations.committed_at`.

#### GET `/api/ai/generations`
- **Description**: List user AI generations (for debugging/audit; optional in UI).
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Query params**
  - `limit`, `cursor`
  - `committed` = `true` | `false` (optional)
  - `deckId` (optional)
  - `sort` = `created_at:desc` (default) | `created_at:asc`
- **Response JSON (200)**

```json
{
  "data": [
    { "id": "uuid", "deckId": "uuid-or-null", "createdAt": "iso", "committedAt": "iso-or-null" }
  ],
  "meta": { "nextCursor": "opaque-or-null", "requestId": "..." }
}
```

#### GET `/api/ai/generations/{generationId}`
- **Description**: Fetch generation metadata and (if committed) its stored final states.
- **Auth**: required
- **Preconditions**: `emailVerified = true`
- **Response JSON (200)**

```json
{
  "data": {
    "generation": {
      "id": "uuid",
      "deckId": "uuid-or-null",
      "createdAt": "iso",
      "committedAt": "iso-or-null"
    },
    "finalStates": [
      { "index": 1, "finalState": "accepted_unchanged" }
    ]
  },
  "meta": { "requestId": "..." }
}
```

- **Errors**
  - `404 NOT_FOUND`
  - `401 UNAUTHENTICATED`
  - `403 EMAIL_NOT_VERIFIED`

---

## 3. Uwierzytelnianie i autoryzacja

### 3.1 Authentication mechanism

- **Supabase Auth** with email+password.
- API must authenticate requests by resolving the current user session, either via:
  - **Bearer token** (`Authorization` header), or
  - **HTTP-only cookies** (server reads cookies and forwards/attaches the Supabase access token for DB queries).

### 3.2 Authorization rules (PRD-driven)

- **All product endpoints** (decks, cards, AI) require:
  - authenticated user (`401 UNAUTHENTICATED` otherwise)
  - verified email (`403 EMAIL_NOT_VERIFIED` otherwise)
- Exceptions:
  - `POST /api/auth/resend-verification` is allowed while unverified (and optionally unauthenticated, depending on UX choice).
  - `GET /api/me` is allowed for authenticated users regardless of verification (used to show the “verify email” banner + resend).

### 3.3 Data isolation

Recommended approach (matches repo migration):
- Use **RLS** as the hard boundary, by running DB queries with the user JWT.
- API additionally validates ownership when referencing resources by id and returns `404 NOT_FOUND` for non-owned resources (do not leak existence).

Admin-only approach (limited use):
- Use **service role** only where user JWT cannot perform action (e.g. delete auth user).
- When using service role, always scope by `auth.userId` and never accept “userId” from client input.

### 3.4 Rate limiting & abuse protection (PRD + cost control)

Apply rate limiting to:
- `POST /api/auth/sign-in` (brute force)
- `POST /api/auth/resend-verification` (spam)
- `POST /api/ai/generations` (cost + abuse)

Suggested policy (per user where possible, else per IP):
- **AI generation**: e.g. 10 requests / 10 minutes / user
- **Resend verification**: e.g. 3 requests / hour / user/email
- **Sign-in**: e.g. 10 attempts / 10 minutes / IP + email

Return:
- `429 RATE_LIMITED` and `Retry-After` header.

---

## 4. Walidacja i logika biznesowa

### 4.1 Validation (mirrors DB constraints)

#### Decks (`public.decks`)
- **name required** and **non-blank** (`CHECK length(trim(name)) > 0`)
- **name unique per user** case-insensitive + trim (`UNIQUE (user_id, name_normalized)`)
- **description optional**

API behavior:
- Trim input on server, but still rely on DB constraint.
- Map unique violation to `409 DECK_NAME_NOT_UNIQUE`.

#### Cards (`public.cards`)
- **deck_id required**
- **front/back required, non-blank**
- **front/back max length 500** (DB checks)
- **source** must be `manual` or `ai` (DB check)
- **ai_generation_id** optional

API behavior:
- Manual create sets `source="manual"`, `aiGenerationId=null`.
- AI commit sets `source="ai"`, `aiGenerationId=generationId`.

#### AI generations (`public.ai_generations`)
- `committed_at IS NULL OR deck_id IS NOT NULL` (commit requires deck)

API behavior:
- `POST /api/ai/generations` always creates `committedAt=null`.
- `POST /api/ai/generations/{id}/commit` must set both `deckId` and `committedAt=now()`.

#### AI suggestions (`public.ai_suggestions`)
- `suggestion_index` in `[1..20]`
- unique `(generation_id, suggestion_index)`
- `final_state` enum: `accepted_unchanged | accepted_edited | removed`

API behavior:
- Enforce unique indices in request.
- Enforce allowed range.
- Insert final states for each reviewed suggestion index.

### 4.2 PRD business logic mapping to API

- **Email verification gate**: block product actions until verified
  - Enforced by middleware/guards on all product endpoints (`403 EMAIL_NOT_VERIFIED`).
- **AI input limit**: text must be non-empty and ≤ 10,000 chars
  - Enforced in `POST /api/ai/generations`.
- **AI output validation**: reject invalid AI response format (missing front/back, empty list)
  - Enforced server-side; return `502 AI_PROVIDER_ERROR` or `500 INTERNAL_ERROR` with safe message; client can “Try again”.
- **Review & accept/edit/remove each suggestion**
  - Client decides; server persists only final states via `/commit`.
- **Commit saves only accepted suggestions**
  - `/commit` inserts cards only for `accepted_unchanged` and `accepted_edited`.
- **Regeneration discards local edits**
  - Because suggestion content is not stored server-side, regeneration is simply a new call to `POST /api/ai/generations` with the same text. The client is responsible for showing the confirmation dialog and replacing local state.

### 4.3 Transactionality requirements

`POST /api/ai/generations/{id}/commit` should be executed as a single transaction:
- validate request
- validate ownership and deck ownership
- insert `ai_suggestions` rows (final_state per index)
- insert `cards` for accepted decisions
- update `ai_generations` with `deck_id` + `committed_at`

If any step fails, nothing is committed (atomicity), and the API returns a clear error without partial writes.

---

## Appendix: Suggested DTOs (shared in `src/types.ts`)

> Recommended to centralize these DTOs to keep client/server aligned (PRD + clean code practices).

- `DeckDTO`
- `CardDTO`
- `UserDTO` (`emailVerified` boolean)
- `AiSuggestionDTO` (ephemeral: `index, front, back`)
- `AiGenerationDTO` (`id, deckId, createdAt, committedAt`)
- `ApiErrorDTO` (`code, message, details`)

