# Dokument wymagań produktu (PRD) - Fiszki AI (MVP)
## 1. Przegląd produktu
### 1.1 Cel produktu
Celem MVP jest przyspieszenie tworzenia wysokiej jakości fiszek do nauki metodą spaced repetition poprzez generowanie propozycji fiszek przez AI na podstawie wklejonego tekstu, z jednoczesnym zachowaniem kontroli jakości po stronie użytkownika (akceptacja/edycja/usunięcie).

### 1.2 Grupa docelowa
Osoby przygotowujące się do egzaminu B2 First (FCE), uczące się słownictwa i definicji w języku angielskim.

### 1.3 Kontekst użycia i platforma
- Platforma: aplikacja web (desktop web).
- Model nauki: spaced repetition z wykorzystaniem gotowego (open-source) algorytmu powtórek.
- Organizacja treści: wyłącznie zestawy (decks); brak tagów/kategorii.

### 1.4 Najmniejszy zestaw funkcjonalności (MVP)
- Generowanie fiszek przez AI na podstawie wprowadzonego tekstu (kopiuj-wklej).
- Manualne tworzenie fiszek.
- Przeglądanie, edycja i usuwanie fiszek.
- Prosty system kont użytkowników do przechowywania fiszek.
- Integracja z gotowym algorytmem powtórek i prosta sesja nauki.

### 1.5 Założenia kluczowe (ustalone)
- Format fiszek: wyłącznie przód/tył (front/back).
- Treść i kierunek: słownictwo + definicje, EN→EN; użytkownik nie wybiera trybu.
- Wejście do AI: angielski tekst lub fragment tekstu, limit 10 000 znaków.
- AI generuje listę 10 propozycji fiszek.
- Użytkownik przegląda listę i dla każdej fiszki wykonuje: zaakceptuj / edytuj / usuń.
- Zapis do zestawu następuje dopiero po finalnej akceptacji listy.
- Regeneracja: użytkownik może ponownie uruchomić generowanie z tego samego tekstu; jeśli regeneruje w trakcie edycji listy, aktualna lista i zmiany przepadają (brak wersjonowania).
- Weryfikacja email jest obowiązkowa i blokuje wszystkie akcje produktowe do czasu weryfikacji.
- Brak dodatkowych mechanizmów kontroli jakości AI poza weryfikacją użytkownika.
- Powtórki (nauka) wykorzystują gotowy, darmowy, open-source algorytm jako bibliotekę (np. SM-2 lub FSRS).
- W sesji nauki użytkownik ocenia kartę 4 przyciskami: Again, Hard, Good, Easy.
- Przebieg karty: front → pokaż odpowiedź → ocena → następna karta.
- Globalny limit dzienny: maksymalnie 50 kart łącznie (review + new).
- Dobór kolejki dla sesji (start z poziomu zestawu): najpierw review (due) sortowane rosnąco po due (najbardziej zaległe pierwsze), a jeśli zostaje limit, dobierane są new w kolejności utworzenia (oldest first).
- Sesja nie jest wznawialna: przerwanie kończy sesję; ponowny start wylicza aktualną kolejkę na dziś.
- Zaległe due kumulują się bez dodatkowych limitów; jedyne ograniczenie to limit dzienny 50.
- Nie obsługujemy scenariusza równoległych sesji na tym samym zestawie (np. w dwóch kartach przeglądarki) w MVP.

## 2. Problem użytkownika
### 2.1 Główny problem
Manualne tworzenie wysokiej jakości fiszek edukacyjnych jest czasochłonne, co zniechęca do korzystania z efektywnej metody nauki jaką jest spaced repetition.

### 2.2 Dlaczego to istotne dla grupy docelowej
Osoby uczące się do B2 First (FCE) potrzebują regularnej ekspozycji na słownictwo i definicje. Czas potrzebny na przygotowanie fiszek często przewyższa czas na naukę, przez co użytkownik rezygnuje z metody lub obniża jakość materiału.

### 2.3 Wpływ problemu
- Niska skłonność do rozpoczęcia nauki (próg wejścia).
- Niska regularność (brak przygotowanego materiału).
- Niższa jakość fiszek (skrótowe lub błędne definicje).

### 2.4 Jak MVP rozwiązuje problem
- AI automatyzuje przygotowanie pierwszej wersji fiszek na podstawie wklejonego tekstu.
- Użytkownik weryfikuje i zatwierdza tylko to, co faktycznie trafi do nauki.
- Zestawy umożliwiają utrzymanie porządku i szybkie uruchomienie sesji powtórek.

## 3. Wymagania funkcjonalne
### 3.1 Konto użytkownika i bezpieczeństwo dostępu
3.1.1 Rejestracja
- Użytkownik może utworzyć konto za pomocą email + hasło.
- Po rejestracji system wysyła email weryfikacyjny z linkiem aktywacyjnym ważnym 1 godzinę.
- Użytkownik może ponowić wysyłkę linku (resend) po wygaśnięciu lub w dowolnym momencie.

3.1.2 Weryfikacja email
- Do czasu weryfikacji email użytkownik może:
  - zalogować się,
  - zobaczyć komunikat o konieczności weryfikacji,
  - ponowić wysyłkę emaila weryfikacyjnego.
- Do czasu weryfikacji email użytkownik nie może wykonywać akcji produktowych, w szczególności:
  - tworzyć/edytować/usuwać zestawów,
  - tworzyć/edytować/usuwać fiszek,
  - generować fiszek przez AI,
  - uruchamiać sesji nauki.

3.1.3 Logowanie i wylogowanie
- Użytkownik może zalogować się email + hasło.
- Użytkownik może wylogować się.

3.1.4 Zmiana hasła i usunięcie konta
- Użytkownik (zweryfikowany) może zmienić hasło po podaniu aktualnego hasła oraz nowego hasła.
- Użytkownik (zweryfikowany) może usunąć konto:
  - wymaga potwierdzenia,
  - usuwa lub anonimizuje powiązane dane zgodnie z przyjętą polityką (w MVP: usunięcie zestawów i fiszek użytkownika).

3.1.5 Wymagania bezpieczeństwa (minimalne)
- Hasła są przechowywane w bezpieczny sposób (hashowanie po stronie dostawcy auth).
- Wszystkie operacje na danych są autoryzowane (użytkownik ma dostęp wyłącznie do własnych zestawów i fiszek).
- Tokeny weryfikacyjne email są jednorazowe, wygasają po 1 godzinie i nie mogą być użyte ponownie.

### 3.2 Zestawy (decks)
3.2.1 Model danych zestawu (MVP)
- Pola:
  - nazwa (wymagana),
  - opis (opcjonalny),
  - liczba fiszek w zestawie (wyliczana).

3.2.2 Operacje
- Tworzenie zestawu:
  - użytkownik podaje nazwę, opcjonalnie opis.
- Edycja zestawu:
  - zmiana nazwy i opisu.
- Usuwanie zestawu:
  - wymaga potwierdzenia,
  - usuwa powiązane fiszki zestawu.
- Lista zestawów:
  - pokazuje nazwę, opis (lub skrót), liczbę fiszek, datę ostatniej modyfikacji (jeśli dostępna).
- Szczegóły zestawu:
  - lista fiszek w zestawie,
  - akcje: dodaj fiszkę manualnie, generuj fiszki przez AI, rozpocznij naukę.

### 3.3 Fiszki
3.3.1 Model fiszki (MVP)
- Format: front/back.
- Treść:
  - front: słowo/zwrot w języku angielskim,
  - back: definicja w języku angielskim.
- Limity:
  - front max 500 znaków,
  - back max 500 znaków.

3.3.2 Operacje (CRUD)
- Tworzenie manualne:
  - użytkownik uzupełnia front i back,
  - zapisuje do wybranego zestawu.
- Przeglądanie:
  - lista fiszek w zestawie,
  - podgląd szczegółów fiszki.
- Edycja:
  - użytkownik może zmienić front/back,
  - zapis jest natychmiastowy lub przez przycisk Zapisz (do ustalenia UI; wymagane jest zachowanie spójności).
- Usuwanie:
  - pojedynczej fiszki, z potwierdzeniem.

### 3.4 Generowanie fiszek przez AI
3.4.1 Wejście
- Użytkownik wkleja angielski tekst (do 10 000 znaków).
- System waliduje:
  - niepusty tekst,
  - limit znaków,
  - dostępność użytkownika (zweryfikowany email).

3.4.2 Wyjście i format odpowiedzi AI
- AI zwraca listę propozycji fiszek, każda w formacie:
  - front: słowo/zwrot (EN),
  - back: definicja (EN).
- Liczba propozycji: 10

3.4.3 Przegląd i akceptacja jakości (obowiązkowe)
- Po wygenerowaniu użytkownik trafia do widoku podglądu listy propozycji.
- Dla każdej propozycji użytkownik ma dostęp do akcji:
  - zaakceptuj (bez zmian),
  - edytuj (modyfikacja front/back),
  - usuń (usunięcie z listy).
- Użytkownik może zakończyć proces przyciskiem: zaakceptuj całą listę / zapisz do zestawu.
- Do zapisu trafiają tylko propozycje oznaczone jako zaakceptowane, w tym:
  - zaakceptowane bez zmian,
  - zaakceptowane po edycji.
- Propozycje usunięte nie są zapisywane.

3.4.4 Regeneracja
- Użytkownik może uruchomić ponowne generowanie dla tego samego wejściowego tekstu.
- Regeneracja powoduje utratę bieżącej listy i wszystkich lokalnych zmian (edycji/akceptacji/usunięć) niezapisanych do zestawu.
- System wyraźnie informuje użytkownika o skutku (utrata zmian) przed regeneracją.

3.4.5 Walidacje i ograniczenia
- System musi walidować limity długości front/back po edycji użytkownika oraz w danych z AI (nadmiarowe treści muszą zostać odrzucone z czytelnym błędem; w MVP brak automatycznego skracania bez zgody użytkownika).
- System powinien odrzucić odpowiedź AI, jeśli nie spełnia minimalnego schematu (brak front/back) i poprosić użytkownika o ponowienie generowania.

3.4.6 Minimalne logowanie zdarzeń do metryk
- Dla każdej wygenerowanej propozycji fiszki system zapisuje:
  - identyfikator generacji,
  - identyfikator propozycji w ramach generacji,
  - stan końcowy propozycji: zaakceptowana bez zmian / zaakceptowana po edycji / usunięta,
  - fakt finalnej akceptacji listy (czy zapisano do zestawu).

### 3.5 Nauka (integracja z gotowym algorytmem powtórek)
3.5.1 Założenia
- System korzysta z gotowego, darmowego, open-source algorytmu powtórek jako biblioteki (np. SM-2 lub FSRS).
- Aplikacja nie implementuje własnego, zaawansowanego algorytmu powtórek (jak Anki/SuperMemo); integruje gotowe rozwiązanie.
- Każda karta w sesji jest oceniana jednym z 4 grade: Again, Hard, Good, Easy.
- Stan powtórek jest przechowywany w bazie danych per fiszka.

3.5.2 Sesja nauki (MVP)
- Start sesji:
  - użytkownik uruchamia sesję z poziomu konkretnego zestawu,
  - system wylicza kolejkę na dziś w ramach globalnego limitu 50 kart łącznie (review + new),
  - kolejka jest dobierana w priorytecie:
    - review (karty due) sortowane rosnąco po due (najbardziej zaległe pierwsze),
    - jeśli zostaje limit, dobierane są new w kolejności utworzenia (oldest first).
- Przebieg karty:
  - użytkownik widzi front,
  - użytkownik klika pokaż odpowiedź, aby odsłonić back,
  - przyciski Again/Hard/Good/Easy są zablokowane do momentu odsłonięcia back,
  - wybór oceny zapisuje wynik do algorytmu i przechodzi do następnej fiszki.
- Zaległości:
  - karty due nieprzerobione danego dnia kumulują się bez dodatkowych limitów; jedyne ograniczenie to limit dzienny 50.
- Zakończenie i podsumowanie:
  - sesja kończy się po wyczerpaniu kolejki,
  - UI pokazuje podsumowanie: X/50, rozbicie new/review oraz liczniki ocen Again/Hard/Good/Easy.
- Przerwanie sesji:
  - sesja nie jest wznawialna; przerwanie kończy sesję,
  - ponowne uruchomienie sesji wylicza aktualną kolejkę na dziś.

3.5.3 Spójność z zakresem MVP
- MVP nie zawiera budowy własnego algorytmu, porównywalnego do Anki/SuperMemo.
- MVP nie oferuje zaawansowanych ustawień algorytmu (np. parametry, tryby, personalizacja interwałów) poza tym, co wynika z integracji biblioteki.
- MVP nie oferuje dashboardu agregującego powtórki ze wszystkich zestawów; sesja startuje z poziomu konkretnego zestawu.
- MVP nie obsługuje równoległych sesji na tym samym zestawie (brak blokad/konfliktów).

### 3.6 Wymagania niefunkcjonalne (minimalne, ale krytyczne dla MVP)
- Dostępność: podstawowa obsługa klawiatury w kluczowych formularzach (rejestracja, logowanie, edycja fiszki, akceptacja listy).
- Niezawodność: czytelne komunikaty błędów dla awarii generowania AI, problemów sieciowych oraz błędów walidacji.
- Wydajność: generowanie AI może trwać dłużej; UI musi pokazać stan ładowania i umożliwić bezpieczny powrót (bez utraty zapisanych danych).
- Prywatność: dane użytkownika i jego zestawy są prywatne.

## 4. Granice produktu
### 4.1 Poza zakresem MVP
- Własny, zaawansowany algorytm powtórek (jak SuperMemo, Anki).
- Import wielu formatów (PDF, DOCX itp.).
- Współdzielenie zestawów fiszek między użytkownikami.
- Integracje z innymi platformami edukacyjnymi.
- Aplikacje mobilne (natywne); na start tylko web.
- Tagi/kategorie, wyszukiwanie zaawansowane, statystyki nauki (poza wymaganymi metrykami AI).
- Mechanizmy automatycznej kontroli jakości AI (np. filtrowanie po słownikach, wykrywanie duplikatów) poza walidacją schematu i limitów.

### 4.2 Ograniczenia i decyzje produktowe
- Jedyny typ fiszek: front/back, EN→EN, słownictwo + definicje.
- Brak wyboru trybu nauki i brak explicit grading.
- Twardy limit wejścia do AI: 10 000 znaków.
- Limit długości pól fiszki: 1000 znaków na front i 1000 na back.
- Regeneracja zastępuje bieżącą listę propozycji i usuwa niezapisane zmiany.
- Brak współdzielenia danych i publicznych linków.

## 5. Historyjki użytkowników
### 5.1 Uwierzytelnianie, weryfikacja email i kontrola dostępu
- ID: US-001
  Tytuł: Rejestracja konta email + hasło
  Opis: Jako nowy użytkownik chcę założyć konto, abym mógł przechowywać własne zestawy i fiszki.
  Kryteria akceptacji:
  - Formularz rejestracji wymaga podania poprawnego email oraz hasła.
  - Po poprawnej rejestracji konto jest utworzone w stanie nieweryfikowanym.
  - Po rejestracji system wysyła email weryfikacyjny z linkiem aktywacyjnym.
  - Użytkownik widzi komunikat, że musi zweryfikować email, aby korzystać z aplikacji.
  - Błędy (np. email zajęty, słabe hasło) są pokazane w sposób czytelny i blokują utworzenie konta.

- ID: US-002
  Tytuł: Aktywacja konta linkiem weryfikacyjnym w 1 godzinę
  Opis: Jako nowy użytkownik chcę zweryfikować email linkiem aktywacyjnym, abym mógł korzystać z funkcji aplikacji.
  Kryteria akceptacji:
  - Link aktywacyjny działa tylko raz i wygasa po 1 godzinie od wysłania.
  - Po kliknięciu poprawnego, niewygasłego linku konto przechodzi w stan zweryfikowany.
  - Po weryfikacji użytkownik może wykonywać akcje produktowe (zestawy, fiszki, AI, nauka).
  - Jeśli link jest niepoprawny lub został użyty, użytkownik widzi komunikat o błędzie oraz opcję ponownej wysyłki linku.

- ID: US-003
  Tytuł: Ponowna wysyłka emaila weryfikacyjnego
  Opis: Jako użytkownik nieweryfikowany chcę móc ponowić wysyłkę emaila weryfikacyjnego, abym mógł aktywować konto, gdy link wygaśnie lub email nie dotrze.
  Kryteria akceptacji:
  - Użytkownik może wywołać resend z poziomu aplikacji.
  - Resend wysyła nowy link ważny 1 godzinę.
  - Użytkownik otrzymuje informację o wysłaniu emaila (bez ujawniania wrażliwych danych).
  - System obsługuje przypadek wielokrotnych kliknięć (np. rate limit) komunikatem o konieczności odczekania (jeśli wdrożone).

- ID: US-004
  Tytuł: Logowanie email + hasło
  Opis: Jako użytkownik chcę zalogować się do aplikacji, abym miał dostęp do moich danych.
  Kryteria akceptacji:
  - Formularz logowania wymaga poprawnego email i hasła.
  - Niepoprawne dane powodują komunikat błędu bez ujawniania, czy konto istnieje (w miarę możliwości).
  - Po zalogowaniu użytkownik trafia do aplikacji.
  - Jeśli konto jest nieweryfikowane, użytkownik widzi blokadę funkcji produktowych i wezwanie do weryfikacji.

- ID: US-005
  Tytuł: Wylogowanie
  Opis: Jako zalogowany użytkownik chcę się wylogować, aby zakończyć sesję na współdzielonym urządzeniu.
  Kryteria akceptacji:
  - Po wylogowaniu użytkownik nie ma dostępu do widoków wymagających zalogowania.
  - Próba wejścia w zabezpieczone widoki przekierowuje do logowania.

- ID: US-006
  Tytuł: Blokada akcji produktowych bez weryfikacji email
  Opis: Jako produkt chcę blokować tworzenie i modyfikację danych, dopóki użytkownik nie zweryfikuje email, aby spełnić wymagania bezpieczeństwa.
  Kryteria akceptacji:
  - Użytkownik nieweryfikowany nie może tworzyć/edytować/usuwać zestawów ani fiszek.
  - Użytkownik nieweryfikowany nie może uruchomić generowania AI.
  - Użytkownik nieweryfikowany nie może uruchomić sesji nauki.
  - UI wyświetla spójny komunikat o konieczności weryfikacji oraz zapewnia akcję resend.
  - API odrzuca próby wykonania powyższych akcji przez użytkownika nieweryfikowanego (nawet przy ręcznym wywołaniu).

- ID: US-007
  Tytuł: Zmiana hasła
  Opis: Jako zweryfikowany użytkownik chcę zmienić hasło, aby utrzymać bezpieczeństwo konta.
  Kryteria akceptacji:
  - Zmiana hasła wymaga podania aktualnego hasła oraz nowego hasła.
  - Po poprawnej zmianie hasła użytkownik widzi potwierdzenie.
  - Niepoprawne aktualne hasło blokuje zmianę i wyświetla błąd.

- ID: US-008
  Tytuł: Usunięcie konta
  Opis: Jako zweryfikowany użytkownik chcę usunąć konto, aby zakończyć korzystanie z usługi i usunąć moje dane.
  Kryteria akceptacji:
  - Usunięcie konta wymaga jawnego potwierdzenia (np. wpisania hasła lub kliknięcia potwierdzenia).
  - Po usunięciu konta użytkownik jest wylogowany.
  - Zestawy i fiszki użytkownika są usunięte zgodnie z założeniem MVP.
  - Próba logowania na usunięte konto kończy się błędem.

### 5.2 Zestawy (decks) - CRUD i nawigacja
- ID: US-009
  Tytuł: Utworzenie zestawu
  Opis: Jako zweryfikowany użytkownik chcę utworzyć zestaw, aby organizować fiszki w logiczne grupy.
  Kryteria akceptacji:
  - Użytkownik może utworzyć zestaw z nazwą (wymagana) i opisem (opcjonalny).
  - Pusta nazwa jest blokowana walidacją.
  - Po utworzeniu zestaw pojawia się na liście zestawów.

- ID: US-010
  Tytuł: Edycja zestawu
  Opis: Jako zweryfikowany użytkownik chcę edytować nazwę lub opis zestawu, aby aktualizować jego zawartość i kontekst.
  Kryteria akceptacji:
  - Użytkownik może zmienić nazwę i/lub opis.
  - Pusta nazwa po edycji jest blokowana.
  - Po zapisie zmiany są widoczne na liście i w szczegółach zestawu.

- ID: US-011
  Tytuł: Usunięcie zestawu
  Opis: Jako zweryfikowany użytkownik chcę usunąć zestaw, aby porządkować materiały.
  Kryteria akceptacji:
  - Usunięcie wymaga potwierdzenia.
  - Po usunięciu zestaw znika z listy.
  - Wszystkie fiszki w zestawie są usunięte.
  - Próba wejścia w usunięty zestaw zwraca czytelny komunikat (np. nie znaleziono).

- ID: US-012
  Tytuł: Lista zestawów z liczbą fiszek
  Opis: Jako zweryfikowany użytkownik chcę widzieć listę zestawów i liczbę fiszek w każdym, abym mógł wybrać materiał do nauki.
  Kryteria akceptacji:
  - Lista zestawów wyświetla nazwę i liczbę fiszek.
  - Liczba fiszek jest zgodna ze stanem danych po dodaniu/usunięciu fiszek.
  - Gdy użytkownik nie ma zestawów, widzi stan pusty i CTA do utworzenia zestawu.

- ID: US-013
  Tytuł: Widok szczegółów zestawu
  Opis: Jako zweryfikowany użytkownik chcę wejść w szczegóły zestawu, aby zarządzać fiszkami i rozpocząć naukę.
  Kryteria akceptacji:
  - Widok pokazuje nazwę, opis i listę fiszek.
  - Widok udostępnia akcje: dodaj fiszkę manualnie, generuj przez AI, rozpocznij naukę.
  - Użytkownik widzi stan pusty, gdy zestaw nie zawiera fiszek.

### 5.3 Fiszki - CRUD manualny
- ID: US-014
  Tytuł: Dodanie fiszki manualnie
  Opis: Jako zweryfikowany użytkownik chcę ręcznie dodać fiszkę (front/back), aby uzupełnić zestaw o treści niedostępne w generowaniu AI.
  Kryteria akceptacji:
  - Użytkownik może wprowadzić front i back.
  - Walidacja blokuje zapis, jeśli front lub back są puste.
  - Walidacja blokuje zapis, jeśli front lub back przekracza 1000 znaków.
  - Po zapisie fiszka pojawia się na liście w zestawie.

- ID: US-015
  Tytuł: Przeglądanie listy fiszek w zestawie
  Opis: Jako zweryfikowany użytkownik chcę przeglądać fiszki w zestawie, abym mógł je weryfikować i edytować.
  Kryteria akceptacji:
  - Lista pokazuje co najmniej front oraz back każdej fiszki
  - Gdy zestaw nie ma fiszek, widoczny jest stan pusty i CTA do dodania fiszki.

- ID: US-016
  Tytuł: Edycja fiszki
  Opis: Jako zweryfikowany użytkownik chcę edytować front/back fiszki, aby poprawić definicję lub słowo.
  Kryteria akceptacji:
  - Użytkownik może zmienić front i back.
  - Walidacja blokuje zapis dla pustych pól.
  - Walidacja blokuje zapis po przekroczeniu 1000 znaków dla front/back.
  - Po zapisie zmiany są widoczne na liście i w szczegółach.

- ID: US-017
  Tytuł: Usunięcie fiszki
  Opis: Jako zweryfikowany użytkownik chcę usunąć fiszkę, aby usunąć błędny lub niepotrzebny materiał.
  Kryteria akceptacji:
  - Usunięcie wymaga potwierdzenia.
  - Po usunięciu fiszka znika z listy.
  - Liczba fiszek w zestawie jest zaktualizowana.

### 5.4 Generowanie AI - przepływ end-to-end, akceptacja i regeneracja
- ID: US-018
  Tytuł: Wklejenie tekstu do generowania AI z limitem 10 000 znaków
  Opis: Jako zweryfikowany użytkownik chcę wkleić angielski tekst, aby AI wygenerowało propozycje fiszek.
  Kryteria akceptacji:
  - Pole wejściowe przyjmuje tekst i pokazuje licznik znaków.
  - Tekst pusty blokuje uruchomienie generowania.
  - Tekst powyżej 10 000 znaków blokuje uruchomienie generowania z czytelnym komunikatem.
  - Po kliknięciu generuj UI pokazuje stan ładowania.

- ID: US-019
  Tytuł: Wyświetlenie listy propozycji fiszek wygenerowanych przez AI
  Opis: Jako zweryfikowany użytkownik chcę zobaczyć listę propozycji fiszek po generowaniu, abym mógł je ocenić.
  Kryteria akceptacji:
  - Po sukcesie generowania użytkownik widzi listę propozycji (front/back).
  - UI działa poprawnie dla 1–20 propozycji.
  - Każda propozycja ma akcje: zaakceptuj, edytuj, usuń.
  - Jeśli AI zwróci brak propozycji, UI pokazuje komunikat i możliwość ponowienia.

- ID: US-020
  Tytuł: Akceptacja pojedynczej propozycji bez zmian
  Opis: Jako użytkownik chcę zaakceptować propozycję bez edycji, aby szybko zatwierdzić poprawne fiszki.
  Kryteria akceptacji:
  - Kliknięcie zaakceptuj oznacza propozycję jako zaakceptowaną bez zmian.
  - Użytkownik może cofnąć decyzję (np. odznaczyć) przed finalnym zapisem listy.
  - Stan propozycji jest widoczny w UI.

- ID: US-021
  Tytuł: Edycja propozycji AI i akceptacja po edycji
  Opis: Jako użytkownik chcę edytować propozycję AI, aby poprawić jej jakość przed zapisaniem.
  Kryteria akceptacji:
  - Użytkownik może edytować front i back propozycji.
  - Walidacja limitu 1000 znaków działa dla obu pól.
  - Po zapisaniu edycji propozycja jest oznaczona jako zaakceptowana po edycji (nie liczy się jako zaakceptowana bez zmian).
  - Użytkownik może anulować edycję bez zapisywania zmian.

- ID: US-022
  Tytuł: Usunięcie propozycji z listy
  Opis: Jako użytkownik chcę usunąć propozycję, aby odrzucić niepoprawne fiszki.
  Kryteria akceptacji:
  - Użytkownik może usunąć propozycję z listy (w MVP bez konieczności potwierdzenia na poziomie pojedynczej propozycji lub z potwierdzeniem; zachowanie musi być spójne w całej aplikacji).
  - Propozycja usunięta nie trafia do zapisu.

- ID: US-023
  Tytuł: Finalna akceptacja listy i zapis do zestawu
  Opis: Jako użytkownik chcę zaakceptować całą listę, aby zapisać zaakceptowane propozycje do wybranego zestawu.
  Kryteria akceptacji:
  - Przycisk zapisu jest dostępny tylko, gdy istnieje co najmniej jedna propozycja do zapisania.
  - Po kliknięciu zapisz, system zapisuje do zestawu tylko propozycje zaakceptowane (bez zmian lub po edycji).
  - Po zapisie użytkownik widzi potwierdzenie i wraca do szczegółów zestawu z aktualną listą fiszek.
  - W przypadku błędu zapisu UI pokazuje komunikat i umożliwia ponowienie bez utraty stanów akceptacji/edycji/usunięć.

- ID: US-024
  Tytuł: Regeneracja propozycji z tego samego tekstu
  Opis: Jako użytkownik chcę ponownie wygenerować fiszki z tego samego tekstu, gdy jakość propozycji jest niezadowalająca.
  Kryteria akceptacji:
  - Użytkownik może uruchomić regenerację z widoku propozycji.
  - System pokazuje ostrzeżenie, że niezapisane zmiany przepadną.
  - Po potwierdzeniu regeneracji lista propozycji jest zastąpiona nową.
  - System zachowuje to samo wejściowe źródło tekstu dla regeneracji.

- ID: US-025
  Tytuł: Obsługa błędu generowania AI
  Opis: Jako użytkownik chcę otrzymać czytelny komunikat, gdy generowanie AI się nie powiedzie, abym wiedział co zrobić dalej.
  Kryteria akceptacji:
  - W przypadku błędu sieci lub błędu usługi AI UI pokazuje komunikat o problemie.
  - Użytkownik może ponowić generowanie bez ponownego wklejania tekstu (o ile nie opuścił widoku).
  - System nie zapisuje częściowych wyników jako fiszek.

- ID: US-026
  Tytuł: Odrzucenie niepoprawnego formatu odpowiedzi AI
  Opis: Jako użytkownik chcę odrzucić odpowiedź AI niespełniającą wymagań (brak front/back), aby uniknąć zapisu błędnych danych.
  Kryteria akceptacji:
  - Jeśli odpowiedź AI nie zawiera listy propozycji z polami front/back, UI pokazuje błąd i proponuje ponowienie generowania.
  - System nie tworzy fiszek w bazie danych bez finalnej akceptacji użytkownika.

### 5.5 Nauka (sesje) z gotowym algorytmem powtórek
- ID: US-027
  Tytuł: Uruchomienie sesji nauki dla zestawu
  Opis: Jako zweryfikowany użytkownik chcę uruchomić sesję nauki dla zestawu, aby powtarzać fiszki.
  Kryteria akceptacji:
  - Użytkownik może uruchomić sesję z poziomu szczegółów zestawu.
  - Jeśli zestaw nie ma fiszek, UI blokuje start i pokazuje komunikat.
  - Po starcie użytkownik widzi pierwszą fiszkę zgodnie z kolejką algorytmu.

- ID: US-028
  Tytuł: Przejście przez fiszkę bez oceniania trudności
  Opis: Jako użytkownik chcę przechodzić przez fiszki w sesji bez wybierania oceny, aby nauka była prosta i szybka.
  Kryteria akceptacji:
  - Dla każdej fiszki użytkownik widzi front i może odsłonić back.
  - Użytkownik może przejść do następnej fiszki.
  - UI nie wymaga oceny trudności (brak przycisków typu łatwe/trudne).

- ID: US-029
  Tytuł: Zakończenie sesji i podsumowanie postępu
  Opis: Jako użytkownik chcę zakończyć sesję i zobaczyć podsumowanie, aby wiedzieć, że wykonałem zaplanowaną powtórkę.
  Kryteria akceptacji:
  - Po przejściu przez całą kolejkę sesja kończy się automatycznie.
  - UI pokazuje co najmniej liczbę przerobionych fiszek (X).
  - Użytkownik może wrócić do zestawu po zakończeniu.

### 5.6 Autoryzacja danych i scenariusze skrajne
- ID: US-030
  Tytuł: Brak dostępu do danych innych użytkowników
  Opis: Jako użytkownik chcę mieć pewność, że nikt nie zobaczy moich zestawów ani fiszek.
  Kryteria akceptacji:
  - Użytkownik nie może pobrać ani modyfikować zestawów/fiszek innych użytkowników.
  - Próba wejścia na zasób innego użytkownika skutkuje błędem (np. 404) lub komunikatem o braku uprawnień.
  - API zawsze wymusza autoryzację po stronie serwera.

- ID: US-031
  Tytuł: Obsługa wygaśnięcia sesji (token)
  Opis: Jako użytkownik chcę być poprawnie obsłużony, gdy moja sesja wygaśnie, abym nie tracił orientacji w aplikacji.
  Kryteria akceptacji:
  - Gdy sesja wygaśnie, aplikacja przekierowuje do logowania lub pokazuje komunikat o konieczności ponownego logowania.
  - Operacje zapisu (np. edycja fiszki, zapis listy AI) kończą się czytelnym błędem i nie powodują niespójności danych.

- ID: US-032
  Tytuł: Zachowanie po odświeżeniu strony w trakcie przeglądu propozycji AI
  Opis: Jako użytkownik chcę rozumieć, co stanie się po odświeżeniu, aby nie tracić pracy lub mieć o tym informację.
  Kryteria akceptacji:
  - Jeśli stan przeglądu propozycji AI nie jest utrwalany, UI po odświeżeniu pokazuje komunikat o utracie niezapisanych zmian i umożliwia ponowne generowanie.
  - Jeśli stan jest utrwalany, po odświeżeniu użytkownik widzi ten sam stan listy (akceptacje/edycje/usunięcia).
  - Wybór jednej z opcji jest spójnie wdrożony i przetestowany.

## 6. Metryki sukcesu

### 6.1 Kryteria sukcesu (Primary KPI)
- KPI-001: Co najmniej 75% fiszek wygenerowanych przez AI jest zaakceptowanych bez jakichkolwiek zmian.
  - Definicja: odsetek propozycji AI oznaczonych jako zaakceptowane bez zmian wśród wszystkich propozycji AI, które użytkownik przejrzał w danej generacji lub w skali produktu (w zależności od raportowania).
  - Interpretacja MVP: propozycja jest liczona jako zaakceptowana bez zmian tylko wtedy, gdy użytkownik jej nie edytował (brak jakiejkolwiek modyfikacji front/back) i finalnie została zaakceptowana oraz zapisana.


### 6.2 Wymagany minimalny pomiar i zdarzenia
- Każda generacja AI ma unikalny identyfikator.
- Dla każdej propozycji w generacji zapisujemy stan końcowy:
  - accepted_unchanged (zaakceptowana bez zmian),
  - accepted_edited (zaakceptowana po edycji),
  - removed (usunięta).
- Dodatkowo zapisujemy:
  - liczbę propozycji w generacji,
  - fakt finalnego zapisu listy (commit),
  - identyfikator zestawu, do którego zapisano.
- Dla fiszek zapisanych do bazy:
  - źródło utworzenia: ai lub manual.

### 6.3 Lista kontrolna PRD (weryfikacja wymagań)
- Czy każdą historię użytkownika można przetestować?
  - Tak: każda historia ma mierzalne kryteria akceptacji (walidacje, widoki, stany, zachowanie API/UI).
- Czy kryteria akceptacji są jasne i konkretne?
  - Tak: uwzględniono limity (10 000, 1000), stany (zweryfikowany/nieweryfikowany), oraz warunki błędów.
- Czy mamy wystarczająco dużo historyjek użytkownika, aby zbudować w pełni funkcjonalną aplikację?
  - Tak dla MVP: obejmują pełny zakres konta, zestawów, fiszek, generowania AI z akceptacją i regeneracją oraz sesję nauki.
- Czy uwzględniliśmy wymagania dotyczące uwierzytelniania i autoryzacji?
  - Tak: historie US-001 do US-008 oraz US-030 do US-031 pokrywają rejestrację, weryfikację email, zmianę hasła, usunięcie konta, autoryzację danych i wygaśnięcie sesji.
