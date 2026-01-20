-- migration: create flashcards mvp schema (decks, cards, ai metrics) with rls
-- purpose:
-- - create application tables described in `.ai/db-plan.md`
-- - keep user identity in `auth.users` (no `public.users` table)
-- - enforce per-user isolation via row level security (rls) policies
-- tables/types created:
-- - type: public.ai_suggestion_final_state
-- - table: public.decks
-- - table: public.cards
-- - table: public.ai_generations
-- - table: public.ai_suggestions
-- notes:
-- - this migration uses `gen_random_uuid()` (pgcrypto). on supabase it is typically available; we ensure it here.
-- - ai generation content is intentionally not stored; only final states for kpi.
-- - rls is enabled on all tables. `anon` is denied; `authenticated` is allowed only for owned rows.

begin;

-- ensure uuid generation is available
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- 1) enums
-- -----------------------------------------------------------------------------

-- final state for ai suggestions; stored as an enum for consistency and indexing
do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'ai_suggestion_final_state'
  ) then
    create type public.ai_suggestion_final_state as enum (
      'accepted_unchanged',
      'accepted_edited',
      'removed'
    );
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2) tables
-- -----------------------------------------------------------------------------

-- 2.1) decks: user-owned containers for cards
create table if not exists public.decks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  name_normalized text generated always as (lower(btrim(name))) stored,
  description text null,
  created_at timestamptz not null default now(),
  constraint decks_name_not_blank check (length(trim(name)) > 0),
  constraint decks_user_name_normalized_unique unique (user_id, name_normalized)
);

comment on table public.decks is
  'user-owned decks (flashcard sets). user identity is supabase auth (auth.users).';
comment on column public.decks.user_id is 'owner user id (auth.users.id).';
comment on column public.decks.name_normalized is 'generated stored column for case-insensitive unique per user.';

-- 2.2) cards: flashcards belonging to a deck (user derived via deck)
create table if not exists public.cards (
  id uuid primary key default gen_random_uuid(),
  deck_id uuid not null references public.decks(id) on delete cascade,
  front text not null,
  back text not null,
  source text not null,
  ai_generation_id uuid null,
  created_at timestamptz not null default now(),
  constraint cards_front_not_blank check (length(trim(front)) > 0),
  constraint cards_back_not_blank check (length(trim(back)) > 0),
  constraint cards_front_max_500 check (char_length(front) <= 500),
  constraint cards_back_max_500 check (char_length(back) <= 500),
  constraint cards_source_valid check (source in ('manual', 'ai'))
);

comment on table public.cards is
  'flashcards; ownership is derived from deck_id -> decks.user_id. ai_generation_id is optional audit link (no fk by design).';
comment on column public.cards.source is 'origin of card: manual | ai.';

-- 2.3) ai_generations: one ai generation event (metrics only, no content stored)
create table if not exists public.ai_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  deck_id uuid null references public.decks(id) on delete set null,
  created_at timestamptz not null default now(),
  committed_at timestamptz null,
  constraint ai_generations_commit_requires_deck check (committed_at is null or deck_id is not null)
);

comment on table public.ai_generations is
  'ai generation events/metrics. deck_id is null before commit. committed_at not null indicates final commit.';
comment on column public.ai_generations.committed_at is
  'when set, indicates generation was committed to a deck (kpi counted only for committed).';

-- 2.4) ai_suggestions: store only final state (no suggestion content)
create table if not exists public.ai_suggestions (
  id uuid primary key default gen_random_uuid(),
  generation_id uuid not null references public.ai_generations(id) on delete cascade,
  suggestion_index smallint not null,
  final_state public.ai_suggestion_final_state not null,
  created_at timestamptz not null default now(),
  constraint ai_suggestions_index_range check (suggestion_index between 1 and 20),
  constraint ai_suggestions_generation_index_unique unique (generation_id, suggestion_index)
);

comment on table public.ai_suggestions is
  'ai suggestions (metrics only). stores final state per suggestion index; does not store text content.';

-- -----------------------------------------------------------------------------
-- 3) indexes (crud + kpi)
-- -----------------------------------------------------------------------------

create index if not exists decks_user_id_idx on public.decks (user_id);

create index if not exists cards_deck_id_idx on public.cards (deck_id);
-- optional but commonly useful for "newest first" lists
create index if not exists cards_deck_created_at_idx on public.cards (deck_id, created_at desc);

create index if not exists ai_generations_user_created_at_idx on public.ai_generations (user_id, created_at desc);
-- optional: supports kpi queries only for committed generations
create index if not exists ai_generations_committed_at_idx
  on public.ai_generations (committed_at)
  where committed_at is not null;

create index if not exists ai_suggestions_generation_id_idx on public.ai_suggestions (generation_id);
-- optional: speeds aggregations by final_state within a generation
create index if not exists ai_suggestions_generation_state_idx on public.ai_suggestions (generation_id, final_state);

-- -----------------------------------------------------------------------------
-- 4) row level security (rls) + policies
-- -----------------------------------------------------------------------------
-- we intentionally create explicit policies for both `anon` and `authenticated`.
-- `anon` is denied everywhere. `authenticated` is granted only for owned rows.
--
-- note: service role bypasses rls in supabase, so server-side api can still perform admin operations.

-- 4.1) decks
alter table public.decks enable row level security;

-- select
create policy decks_select_anon
  on public.decks
  for select
  to anon
  using (false);

create policy decks_select_authenticated
  on public.decks
  for select
  to authenticated
  using (user_id = auth.uid());

-- insert
create policy decks_insert_anon
  on public.decks
  for insert
  to anon
  with check (false);

create policy decks_insert_authenticated
  on public.decks
  for insert
  to authenticated
  with check (user_id = auth.uid());

-- update
create policy decks_update_anon
  on public.decks
  for update
  to anon
  using (false)
  with check (false);

create policy decks_update_authenticated
  on public.decks
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- delete
create policy decks_delete_anon
  on public.decks
  for delete
  to anon
  using (false);

create policy decks_delete_authenticated
  on public.decks
  for delete
  to authenticated
  using (user_id = auth.uid());

-- 4.2) cards (ownership derived from deck)
alter table public.cards enable row level security;

-- select
create policy cards_select_anon
  on public.cards
  for select
  to anon
  using (false);

create policy cards_select_authenticated
  on public.cards
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.user_id = auth.uid()
    )
  );

-- insert
create policy cards_insert_anon
  on public.cards
  for insert
  to anon
  with check (false);

create policy cards_insert_authenticated
  on public.cards
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.user_id = auth.uid()
    )
  );

-- update
create policy cards_update_anon
  on public.cards
  for update
  to anon
  using (false)
  with check (false);

create policy cards_update_authenticated
  on public.cards
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.user_id = auth.uid()
    )
  );

-- delete
create policy cards_delete_anon
  on public.cards
  for delete
  to anon
  using (false);

create policy cards_delete_authenticated
  on public.cards
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.decks d
      where d.id = cards.deck_id
        and d.user_id = auth.uid()
    )
  );

-- 4.3) ai_generations (user-owned; optional link to deck must also be owned)
alter table public.ai_generations enable row level security;

-- select
create policy ai_generations_select_anon
  on public.ai_generations
  for select
  to anon
  using (false);

create policy ai_generations_select_authenticated
  on public.ai_generations
  for select
  to authenticated
  using (user_id = auth.uid());

-- insert
create policy ai_generations_insert_anon
  on public.ai_generations
  for insert
  to anon
  with check (false);

create policy ai_generations_insert_authenticated
  on public.ai_generations
  for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and (
      deck_id is null
      or exists (
        select 1
        from public.decks d
        where d.id = ai_generations.deck_id
          and d.user_id = auth.uid()
      )
    )
  );

-- update
create policy ai_generations_update_anon
  on public.ai_generations
  for update
  to anon
  using (false)
  with check (false);

create policy ai_generations_update_authenticated
  on public.ai_generations
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and (
      deck_id is null
      or exists (
        select 1
        from public.decks d
        where d.id = ai_generations.deck_id
          and d.user_id = auth.uid()
      )
    )
  );

-- delete
create policy ai_generations_delete_anon
  on public.ai_generations
  for delete
  to anon
  using (false);

create policy ai_generations_delete_authenticated
  on public.ai_generations
  for delete
  to authenticated
  using (user_id = auth.uid());

-- 4.4) ai_suggestions (ownership derived from generation -> user)
alter table public.ai_suggestions enable row level security;

-- select
create policy ai_suggestions_select_anon
  on public.ai_suggestions
  for select
  to anon
  using (false);

create policy ai_suggestions_select_authenticated
  on public.ai_suggestions
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.ai_generations g
      where g.id = ai_suggestions.generation_id
        and g.user_id = auth.uid()
    )
  );

-- insert
create policy ai_suggestions_insert_anon
  on public.ai_suggestions
  for insert
  to anon
  with check (false);

create policy ai_suggestions_insert_authenticated
  on public.ai_suggestions
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.ai_generations g
      where g.id = ai_suggestions.generation_id
        and g.user_id = auth.uid()
    )
  );

-- update
create policy ai_suggestions_update_anon
  on public.ai_suggestions
  for update
  to anon
  using (false)
  with check (false);

create policy ai_suggestions_update_authenticated
  on public.ai_suggestions
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.ai_generations g
      where g.id = ai_suggestions.generation_id
        and g.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.ai_generations g
      where g.id = ai_suggestions.generation_id
        and g.user_id = auth.uid()
    )
  );

-- delete
create policy ai_suggestions_delete_anon
  on public.ai_suggestions
  for delete
  to anon
  using (false);

create policy ai_suggestions_delete_authenticated
  on public.ai_suggestions
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.ai_generations g
      where g.id = ai_suggestions.generation_id
        and g.user_id = auth.uid()
    )
  );

commit;

