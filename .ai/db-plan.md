# Plan schematu bazy danych PostgreSQL (MVP) — Fiszki AI

Poniższy schemat jest zoptymalizowany pod **Supabase (Postgres + Supabase Auth)** oraz wymagania MVP z PRD i notatek z sesji. Dane aplikacyjne są prywatne per user (wymuszane przez API), a metryki AI są utrzymywane niezależnie od decków.

## 0) Użytkownicy (Supabase Auth) — ważne

- **Nie tworzymy tabeli `public.users`.**
- Źródłem prawdy dla użytkowników jest tabela zarządzana przez Supabase Auth: **`auth.users`**.
- Wszystkie relacje do użytkownika w schemacie aplikacji wskazują na **`auth.users(id)`** (np. `decks.user_id`, `ai_generations.user_id`).

To jest kluczowe: jeśli migracje utworzą osobną `public.users`, nie dostaniesz „dobrodziejstw” Supabase Auth (weryfikacja email, hashowanie haseł, sesje, polityki itp.) i pojawi się ryzyko niespójności danych.

## 1) Lista tabel (kolumny, typy, ograniczenia)

### 1.1 `public.decks`
Zestawy fiszek należące do użytkownika.

- **`id`**: `uuid` **PK**, `default gen_random_uuid()`
- **`user_id`**: `uuid` **NOT NULL**, **FK** → `auth.users(id)` **ON DELETE CASCADE**
- **`name`**: `text` **NOT NULL**
- **`name_normalized`**: `text` **GENERATED ALWAYS AS** (`lower(btrim(name))`) **STORED**
  - normalizacja pod unikalność: case-insensitive + trim (bez zależności od API)
- **`description`**: `text` NULL
- **`created_at`**: `timestamptz` **NOT NULL**, `default now()`

**Constraints**
- **`decks_name_not_blank`**: `CHECK (length(trim(name)) > 0)`
- **`decks_user_name_normalized_unique`**: `UNIQUE (user_id, name_normalized)`  
  (unikalność nazwy decka w obrębie usera, case-insensitive + trim)

**Uwagi implementacyjne**
- Wariant rekomendowany to **generated column** (powyżej). Alternatywnie można użyć unikalnego indeksu na wyrażeniu `UNIQUE (user_id, lower(btrim(name)))` bez osobnej kolumny.

---

### 1.2 `public.cards`
Fiszki należące do jednego decka (bez `user_id` w tabeli, user wynika z decka).

- **`id`**: `uuid` **PK**, `default gen_random_uuid()`
- **`deck_id`**: `uuid` **NOT NULL**, **FK** → `public.decks(id)` **ON DELETE CASCADE**
- **`front`**: `text` **NOT NULL**
- **`back`**: `text` **NOT NULL**
- **`source`**: `text` **NOT NULL**  
  dozwolone wartości: `manual`, `ai`
- **`ai_generation_id`**: `uuid` NULL  
  opcjonalny link audytowy (nie wymagany do KPI)
- **`created_at`**: `timestamptz` **NOT NULL**, `default now()`

**Constraints**
- **`cards_front_not_blank`**: `CHECK (length(trim(front)) > 0)`
- **`cards_back_not_blank`**: `CHECK (length(trim(back)) > 0)`
- **`cards_front_max_500`**: `CHECK (char_length(front) <= 500)`
- **`cards_back_max_500`**: `CHECK (char_length(back) <= 500)`
- **`cards_source_valid`**: `CHECK (source IN ('manual', 'ai'))`

**Uwagi implementacyjne**
- Duplikaty fiszek są dozwolone (brak unikalności np. po `front`).
- `ai_generation_id` można wypełniać przy commicie AI, ale to opcjonalne; w MVP można też **nie definiować FK** dla tego pola, aby metryki mogły żyć niezależnie od cyklu życia fiszek.

---

### 1.3 `public.ai_generations`
Jedna generacja AI (metryki), tworzona przez użytkownika. **Treść inputu ani propozycji nie jest przechowywana.**

- **`id`**: `uuid` **PK**, `default gen_random_uuid()`
- **`user_id`**: `uuid` **NOT NULL**, **FK** → `auth.users(id)` **ON DELETE CASCADE**
- **`deck_id`**: `uuid` NULL, **FK** → `public.decks(id)` **ON DELETE SET NULL**
  - `NULL` do czasu commitu
- **`created_at`**: `timestamptz` **NOT NULL**, `default now()`
- **`committed_at`**: `timestamptz` NULL  
  - `NOT NULL` oznacza, że generacja została finalnie zapisana do decka (KPI liczymy tylko wtedy)

**Constraints**
- **`ai_generations_commit_requires_deck`**:  
  `CHECK (committed_at IS NULL OR deck_id IS NOT NULL)`

---

### 1.4 `public.ai_suggestions`
Propozycje w ramach generacji — przechowujemy **tylko stan końcowy** (bez treści).

> Rekomendowane jest użycie enum dla spójności i indeksowania.

#### Typ enum: `public.ai_suggestion_final_state`
Dozwolone wartości:
- `accepted_unchanged`
- `accepted_edited`
- `removed`

#### Tabela `public.ai_suggestions`
- **`id`**: `uuid` **PK**, `default gen_random_uuid()`
- **`generation_id`**: `uuid` **NOT NULL**, **FK** → `public.ai_generations(id)` **ON DELETE CASCADE**
- **`suggestion_index`**: `smallint` **NOT NULL**  
  porządek propozycji w generacji (1..20)
- **`final_state`**: `public.ai_suggestion_final_state` **NOT NULL**
- **`created_at`**: `timestamptz` **NOT NULL**, `default now()`

**Constraints**
- **`ai_suggestions_index_range`**: `CHECK (suggestion_index BETWEEN 1 AND 20)`
- **`ai_suggestions_generation_index_unique`**: `UNIQUE (generation_id, suggestion_index)`

## 2) Relacje między tabelami (kardynalność)

- **`auth.users (1) → (N) public.decks`** przez `decks.user_id`
- **`public.decks (1) → (N) public.cards`** przez `cards.deck_id`
  - kasowanie decka usuwa fiszki: **ON DELETE CASCADE**
- **`auth.users (1) → (N) public.ai_generations`** przez `ai_generations.user_id`
- **`public.decks (0..1) ← (N) public.ai_generations`** przez `ai_generations.deck_id`
  - `deck_id` jest **NULL przed commitem**
  - usunięcie decka nie usuwa metryk: **ON DELETE SET NULL**
- **`public.ai_generations (1) → (N) public.ai_suggestions`** przez `ai_suggestions.generation_id`

## 3) Indeksy (minimalne pod CRUD i KPI)

### 3.1 Indeksy na `public.decks`
- **`decks_user_id_idx`**: `CREATE INDEX ON public.decks (user_id);`
- **`decks_user_name_normalized_uq`**: unikalny indeks wynikający z `UNIQUE (user_id, name_normalized)`

### 3.2 Indeksy na `public.cards`
- **`cards_deck_id_idx`**: `CREATE INDEX ON public.cards (deck_id);`
  - wspiera listę fiszek w decku oraz `COUNT(*)` dla “liczby fiszek w zestawie”
- (opcjonalnie) **`cards_deck_created_at_idx`**: `CREATE INDEX ON public.cards (deck_id, created_at DESC);`
  - jeśli UI często pokazuje “najnowsze”

### 3.3 Indeksy na `public.ai_generations`
- **`ai_generations_user_created_at_idx`**: `CREATE INDEX ON public.ai_generations (user_id, created_at DESC);`
- (opcjonalnie) **`ai_generations_committed_at_idx`**: `CREATE INDEX ON public.ai_generations (committed_at) WHERE committed_at IS NOT NULL;`
  - przydatne do raportów KPI tylko po committed

### 3.4 Indeksy na `public.ai_suggestions`
- **`ai_suggestions_generation_id_idx`**: `CREATE INDEX ON public.ai_suggestions (generation_id);`
- (opcjonalnie) **`ai_suggestions_generation_state_idx`**: `CREATE INDEX ON public.ai_suggestions (generation_id, final_state);`
  - przyspiesza agregacje KPI w ramach generacji

## 4) Zasady PostgreSQL (RLS)

- **RLS: nie dotyczy (MVP)** — zgodnie z decyzją z sesji, prywatność danych i blokady (email verified) są egzekwowane **wyłącznie w API**.
- Zalecenie bezpieczeństwa (poza MVP): jeśli w przyszłości dojdzie RLS, najlepszą bazą jest izolacja po `decks.user_id` oraz `ai_generations.user_id`, a `cards` izolować przez join do `decks`.

## 5) Dodatkowe uwagi i decyzje projektowe

- **Brak `updated_at`**: tylko `created_at` (zgodnie z sesją).
- **Brak soft-delete**: twarde usuwanie; `cards` kasują się z deckiem (CASCADE).
- **Liczba fiszek w decku**: wyliczana w locie `COUNT(*)` po `cards(deck_id)` (bez liczników/triggerów).
- **Metryki AI bez treści**: nie zapisujemy inputu ani propozycji; zapisujemy tylko `final_state` dla KPI.
- **KPI**: liczyć wyłącznie dla generacji z `committed_at IS NOT NULL`.
- **Unikalność nazwy decka**: zapewniona przez `UNIQUE (user_id, name_normalized)`; `name_normalized` jest liczone w DB jako **generated stored column**: `lower(btrim(name))` (case-insensitive + trim).
- **UUID**: jeśli używasz `gen_random_uuid()`, upewnij się, że jest dostępne rozszerzenie `pgcrypto` (w Supabase jest standardowo włączone).
