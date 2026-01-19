# Tech stack — analiza dopasowania do PRD (Fiszki AI, MVP)

Poniżej znajduje się krytyczna, rzeczowa ocena zaproponowanego stacku względem wymagań z `prd.md` (MVP): auth z obowiązkową weryfikacją email, prywatność danych per user, CRUD decków i fiszek oraz generowanie propozycji fiszek przez AI (walidacje + metryki).

## Tech stack (propozycja)
- **Frontend**: Astro 5, React 19, TypeScript 5, Tailwind 4, shadcn/ui
- **Backend i baza danych**: Supabase
- **Komunikacja z modułami AI**: Openrouter.ai
- **CI/CD + hosting**: GitHub Actions, DigitalOcean

## 1) Czy technologia pozwoli nam szybko dostarczyć MVP?
- **Astro 5 + React 19 + TypeScript**: tak, to dobry zestaw do szybkiego dowiezienia UI + endpointów (Astro) oraz dynamicznych widoków (React islands) dla generatora i widoków edycji listy propozycji. Ryzyko: łatwo „przepalić” czas, budując pełną SPA w Astro i komplikując routing/stan.
- **Tailwind 4 + shadcn/ui**: zwykle przyspiesza MVP (formularze, dialogi, layout), ale zwiększa liczbę elementów do utrzymania (aktualizacje, spójność komponentów).
- **Supabase**: bardzo dobry wybór do tego PRD; skraca czas przez gotowy **Auth**, **email verification**, **Postgres** i możliwość wdrożenia **RLS**.
- **Openrouter.ai**: przyspiesza iteracje (łatwiejsza wymiana modeli / koszt-jakość), ale wymaga solidnej warstwy serwerowej (sekrety, limity, logowanie błędów).
- **GitHub Actions + DigitalOcean**: może być szybko, ale bywa hamulcem na MVP, jeśli wchodzicie w self-managed infra (TLS, reverse proxy, monitoring, backupy, skalowanie).

**Wniosek**: stack jest **MVP-friendly**, ale największe ryzyko spowolnienia to **ops na DigitalOcean** oraz zbyt szerokie użycie warstw frontendu.

## 2) Czy rozwiązanie będzie skalowalne w miarę wzrostu projektu?
- **Supabase/Postgres**: skaluje się sensownie dla prywatnych danych per user i prostych relacji (decks, cards).
- Potencjalne wąskie gardła przy wzroście:
  - **koszt/limity AI** (nadużycia, spam generacji),
  - **rate limiting** i ochrona endpointów.
- **Astro/React**: skaluje się organizacyjnie i wydajnościowo, o ile interaktywne części pozostaną „wyspami”, a nie całą aplikacją po stronie klienta.

**Wniosek**: rozwiązanie jest **wystarczająco skalowalne** dla kierunku MVP→produkt, ale wymaga od początku zaprojektowania ochrony i limitów dla AI.

## 3) Czy koszt utrzymania i rozwoju będzie akceptowalny?
- Największy koszt zwykle generuje **AI**, nie framework.
- **Supabase**: kosztowo zwykle bardzo OK na start; rośnie wraz z ruchem/DB, ale nadal często jest tańszy niż własny backend + auth + DB + operacje.
- **DigitalOcean**: koszt „czasowy” utrzymania rośnie, jeśli wybierzecie self-managed podejście.

**Wniosek**: koszt utrzymania będzie **akceptowalny**, jeśli ograniczycie „ops overhead” oraz wprowadzicie kontrolę kosztów AI (limity, metryki, monitoring).

## 4) Czy potrzebujemy aż tak złożonego rozwiązania?
- **Frontend**: Astro + React + Tailwind + shadcn to standard, ale może być „więcej niż trzeba” na MVP, jeśli React trafi do miejsc, gdzie wystarczy statyczne Astro.
- **CI/CD + DO**: tutaj najłatwiej o przerost (pipeline’y, konfiguracja środowisk, utrzymanie serwera) bez proporcjonalnej wartości na wczesnym etapie.

**Wniosek**: front jest **umiarkowanie złożony, ale uzasadniony** (generator i przegląd listy propozycji), natomiast infrastruktura na DO może być **nadmiarowa** na MVP.

## 5) Czy istnieje prostsze podejście, które spełni nasze wymagania?
Opcje uproszczeń (zachowując funkcjonalność z PRD):
- **Astro + TypeScript + Tailwind (bez React)**: możliwe, ale ryzykowne ergonomicznie przy złożonych stanach (edycja listy propozycji).
- **Astro + React, ale bez shadcn/ui**: jeśli UI ma być minimalistyczne i zespół woli pisać komponenty ręcznie.
- **Hosting bez DO**: wybór platformy, która minimalizuje ops (szczególnie dla SSR/edge) — szybciej na MVP.
- **AI bez Openrouter** (1 provider): mniej zależności i prostsze debugowanie; mniej elastyczności w doborze modeli i kosztów.

**Wniosek**: da się uprościć, ale największy „quick win” zwykle daje **uprość hosting/ops**, a nie cięcie frontendu.

## 6) Czy technologie pozwolą nam zadbać o odpowiednie bezpieczeństwo?
- **Supabase** daje solidne podstawy: bezpieczne przechowywanie haseł, sesje, email verification i kluczowo **RLS** (PRD wymaga twardo: użytkownik ma dostęp wyłącznie do swoich danych).
- Elementy krytyczne, o które stack sam nie zadba:
  - **klucze do Openrouter nigdy nie trafiają do klienta** (wywołania tylko przez endpoint serwerowy),
  - **rate limiting / anty-abuse** dla generowania AI oraz resend email,
  - **walidacja schematu odpowiedzi AI** + twarde limity długości pól (PRD: odrzucać niepoprawne dane),
  - **autoryzacja po stronie serwera** (PRD: API ma wymuszać autoryzację nawet przy ręcznych wywołaniach).

**Wniosek**: stack pozwala na **bezpieczne MVP**, pod warunkiem konsekwentnego podejścia: RLS jako źródło prawdy + serwerowe wywołania AI + limity.

## Podsumowanie
- **Dobór technologii jest trafny** dla MVP z PRD, szczególnie dzięki Supabase (Auth + RLS + DB).
- Największe ryzyko przerostu i kosztu czasu to **DigitalOcean w modelu self-managed** oraz zbyt szerokie użycie warstw frontendu.
- Jeśli priorytetem jest szybkość MVP: postawcie na **AI tylko przez serwer**, **limity/rate limiting** oraz **RLS** jako podstawę izolacji danych; rozważcie też **uproszczenie hostingu** dla minimalizacji ops.

