## API Endpoint Implementation Plan: GET `/api/decks/{deckId}`

## 1. Przegląd punktu końcowego
- **Cel**: zwrócić szczegóły pojedynczego decka należącego do zalogowanego użytkownika, wraz z wyliczoną liczbą fiszek (`cardCount`).
- **Specyfikacja źródłowa**: `.ai/api-plan.md` → `GET /api/decks/{deckId}`.
- **Baza danych**: `public.decks`, `public.cards` (licznik po `cards.deck_id`), RLS włączone w migracji `supabase/migrations/20260120120000_create_flashcards_mvp_schema.sql`.
- **Autoryzacja**:
  - `401 UNAUTHENTICATED` jeśli brak sesji/JWT.
  - `403 EMAIL_NOT_VERIFIED` jeśli email niezweryfikowany (bramka produktowa).
  - `404 NOT_FOUND` jeśli deck nie istnieje **lub** nie jest własnością użytkownika (brak wycieku informacji).

## 2. Szczegóły żądania
- **Metoda HTTP**: `GET`
- **Struktura URL**: `/api/decks/{deckId}`
- **Parametry**:
  - **Wymagane**:
    - `deckId` (path param): UUID decka.
  - **Opcjonalne**: brak
- **Nagłówki**:
  - **Wymagane** (jeden z wariantów):
    - `Authorization: Bearer <access_token>` (rekomendowane dla MVP, bo proste do wdrożenia i testowania), **albo**
    - cookies sesyjne Supabase (wariant przyszłościowy; wymaga poprawnego “server-side session bridging”).
- **Request Body**: brak

## 3. Wykorzystywane typy
Z `src/types.ts`:
- **DTO**:
  - `DeckSummaryDTO`
  - `GetDeckResponseData` (`type GetDeckResponseData = DeckSummaryDTO`)
  - `ApiSuccessResponse<GetDeckResponseData>`
  - `ApiErrorResponse<...>`
  - `ApiErrorCode` (używane kody: `VALIDATION_ERROR`, `UNAUTHENTICATED`, `EMAIL_NOT_VERIFIED`, `NOT_FOUND`, `INTERNAL_ERROR`)
- **Brak Command Model** (endpoint tylko do odczytu).

## 4. Szczegóły odpowiedzi
- **200 OK**:
  - Body: `ApiSuccessResponse<GetDeckResponseData>`
  - `data`:
    - `id`, `name`, `description`, `createdAt`, `cardCount`
  - `meta`:
    - `requestId: string`
- **Błędy** (envelope zgodny z `.ai/api-plan.md`):
  - `400 VALIDATION_ERROR`: niepoprawny `deckId` (np. nie-UUID).
  - `401 UNAUTHENTICATED`: brak/niepoprawny token, brak użytkownika.
  - `403 EMAIL_NOT_VERIFIED`: użytkownik zalogowany, ale email niepotwierdzony.
  - `404 NOT_FOUND`: deck nie istnieje lub nie jest dostępny dla użytkownika (RLS/ownership).
  - `500 INTERNAL_ERROR`: błąd po stronie serwera (np. Supabase/DB, wyjątek runtime).

## 5. Przepływ danych
1. **Astro API route** odbiera request na `/api/decks/{deckId}`.
2. **Walidacja wejścia** (Zod):
   - parse `deckId` z paramów trasy i sprawdź `uuid`.
3. **Uwierzytelnienie + JWT bridging do Supabase (RLS)**:
   - wyciągnij `access_token` z `Authorization` (Bearer),
   - zbuduj klienta Supabase “per-request” z nagłówkiem `Authorization: Bearer <token>` i zapisz do `context.locals.supabase`,
   - pobierz użytkownika przez Supabase (`supabase.auth.getUser()`), aby potwierdzić ważność tokena i uzyskać `email_confirmed_at`.
4. **Bramka email-verified**:
   - jeśli `email_confirmed_at` jest puste → zwróć `403 EMAIL_NOT_VERIFIED`.
5. **Pobranie decka (RLS + brak wycieku)**:
   - Query 1: `public.decks` po `id = deckId` (z RLS, więc zwróci 0 wierszy, jeśli nie-owner),
   - jeśli brak danych → `404 NOT_FOUND`.
6. **Wyliczenie `cardCount`**:
   - Query 2: `public.cards` count po `deck_id = deckId` (head+count) albo `select('id', { count: 'exact', head: true })`.
7. **Mapowanie do DTO + envelope**:
   - `created_at` → `createdAt`,
   - dołącz `cardCount`,
   - odpowiedź `200` z `{ data, meta: { requestId } }`.

## 6. Względy bezpieczeństwa
- **RLS jako twarda izolacja**:
  - Migracja włącza RLS i polityki dla `decks` i `cards`; endpoint musi wykonywać zapytania z JWT użytkownika (nie anon).
  - W przeciwnym razie wszystkie odczyty będą odrzucane (lub zwrócą puste wyniki), co popsuje semantykę 401/404.
- **Nie ujawniaj istnienia zasobu**:
  - Dla zasobu nieposiadanego przez usera zwracaj `404 NOT_FOUND`, a nie `403`.
  - Utrzymuj spójność (tak samo dla “brak” i “nie-owner”).
- **Weryfikacja email**:
  - Endpoint produktowy ma być blokowany do czasu `emailVerified=true` (`403 EMAIL_NOT_VERIFIED`), zgodnie z `.ai/api-plan.md`.
- **Walidacja wejścia**:
  - `deckId` musi być UUID (400 przy błędzie).
  - Brak query/body → brak dodatkowych walidacji.
- **Klucze Supabase**:
  - Publiczny `anon` key jest OK w backendzie tylko jako “transport” z JWT; nie wolno używać service role dla zwykłego CRUD.
- **CSRF**:
  - Dla wariantu Bearer (Authorization) ryzyko CSRF jest minimalne.
  - Jeśli przejdziemy na cookies: wprowadzić ochronę CSRF dla metod mutujących; ten endpoint to `GET`, ale spójna polityka powinna być opisana w middleware.

## 7. Obsługa błędów
### Scenariusze i mapowanie
- **Niepoprawny `deckId` (nie-UUID)**:
  - HTTP `400`
  - `code: "VALIDATION_ERROR"`
  - `details.fieldErrors.deckId = ["Invalid UUID"]`
- **Brak `Authorization` / brak usera**:
  - HTTP `401`
  - `code: "UNAUTHENTICATED"`
- **Email niezweryfikowany**:
  - HTTP `403`
  - `code: "EMAIL_NOT_VERIFIED"`
- **Deck nie istnieje / nie-owner (RLS)**:
  - HTTP `404`
  - `code: "NOT_FOUND"`
- **Błąd Supabase/DB lub wyjątek runtime**:
  - HTTP `500`
  - `code: "INTERNAL_ERROR"`

### Rejestrowanie błędów (“tabela błędów”)
- W obecnym schemacie **nie ma tabeli do logowania błędów** (ani w `.ai/db-plan.md`, ani w migracji).
- Minimalny standard dla MVP:
  - generować `requestId` per request,
  - logować `console.error({ requestId, route, error })` po stronie serwera,
  - zwracać bezpieczny komunikat w `ApiErrorDTO.message` (bez szczegółów wrażliwych).

## 8. Wydajność
- **Liczba zapytań**: 2 zapytania do DB (deck + count).
  - To jest OK dla MVP; oba zapytania są po indeksach (`decks.id` PK, `cards_deck_id_idx`).
- **Możliwe usprawnienie (opcjonalne)**:
  - Jeden round-trip przez widok/RPC lub `select` z agregacją po stronie SQL.
  - Na MVP lepiej utrzymać prostotę i czytelność, chyba że endpoint jest “hot path”.
- **Caching**:
  - Nie cache’ować współdzielnie między userami.
  - Opcjonalnie: krótkie cache per-user (np. w CDN tylko jeśli `Authorization` nie jest używany, co tu nie zachodzi).

## 9. Kroki implementacji
1. **Utwórz Astro API route**:
   - plik: `src/pages/api/decks/[deckId].ts`
   - dodaj `export const prerender = false`
   - implementuj `export async function GET(context)`
2. **Dodaj walidację Zod**:
   - schema dla paramów: `{ deckId: z.string().uuid() }`
   - przy błędzie zwróć `400 VALIDATION_ERROR` z `fieldErrors`.
3. **Zaimplementuj request context dla Supabase (RLS)**:
   - preferowane: w `src/middleware/index.ts` budować klienta Supabase per-request:
     - wyciągać Bearer token,
     - tworzyć klienta z `global.headers.Authorization`,
     - przypinać do `context.locals.supabase`.
   - (alternatywnie na start) zrobić to lokalnie w route, ale docelowo wspólnie dla wszystkich endpointów.
4. **Zaimplementuj guardy auth/verified jako współdzielone helpery** (żeby nie dublować logiki w kolejnych endpointach):
   - `src/lib/services/auth.guard.ts` (lub podobnie):
     - `requireUser(context)` → `{ user, emailVerified }` albo zwraca gotową odpowiedź 401/403.
   - używać `context.locals.supabase` (zgodnie z regułami).
5. **Wyodrębnij logikę domenową do serwisu**:
   - `src/lib/services/decks.service.ts`
   - funkcja np. `getDeckSummary({ supabase, deckId }): Promise<DeckSummaryDTO | null>`
   - serwis odpowiada za zapytania do `decks` i `cards` oraz mapowanie do DTO.
6. **Zbuduj spójne odpowiedzi**:
   - helpery np. w `src/lib/api/response.ts`:
     - `ok(data, requestId)` / `fail(status, code, message, details, requestId)`
   - zawsze zwracaj `meta.requestId` (sukces i błąd).
7. **Obsłuż błędy Supabase**:
   - mapuj brak wiersza → `404 NOT_FOUND`
   - inne błędy z Supabase → `500 INTERNAL_ERROR`
   - loguj po stronie serwera z `requestId`.
8. **Testy manualne (min.)**:
   - brak tokena → 401
   - token usera z niezweryfikowanym email → 403
   - token verified + nieistniejący deckId (uuid) → 404
   - token verified + deckId należący do usera → 200 + poprawne `cardCount`
   - token verified + deckId cudzy → 404 (nie 403)

