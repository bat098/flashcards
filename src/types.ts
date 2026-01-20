// Shared DTOs + Command Models for API contract (.ai/api-plan.md)
// These types are intentionally "DB-aware": field types are derived from Supabase `Tables<>`/`Enums<>`
// while shapes follow the REST API (camelCase, response envelopes).

import type { Enums, Tables } from "./db/database.types";

// ----------------------------
// DB-derived primitives
// ----------------------------

type DeckRow = Tables<"decks">;
type CardRow = Tables<"cards">;
type AiGenerationRow = Tables<"ai_generations">;
type AiSuggestionRow = Tables<"ai_suggestions">;

/** ISO date string returned by Postgres/Supabase (e.g. `created_at`, `committed_at`). */
export type IsoDateString = DeckRow["created_at"];

export type DeckId = DeckRow["id"];
export type CardId = CardRow["id"];
export type AiGenerationId = AiGenerationRow["id"];

/** In DB this is a FK to `auth.users.id` stored on multiple tables. */
export type UserId = DeckRow["user_id"];

/** DB enum, reused across API (commit decisions, final states). */
export type AiSuggestionFinalState = Enums<"ai_suggestion_final_state">;

/** DB column is `string`, but DB constraint limits it to `"manual" | "ai"` (see migration). */
export type CardSource = Extract<CardRow["source"], "manual" | "ai">;

// ----------------------------
// Response envelopes (global API convention)
// ----------------------------

export interface ApiMetaBase {
  requestId: string;
}

export interface ApiCursorPaginationMeta extends ApiMetaBase {
  nextCursor: string | null;
}

export interface ApiSuccessResponse<TData, TMeta extends ApiMetaBase = ApiMetaBase> {
  data: TData;
  meta: TMeta;
}

export type FieldErrors = Record<string, string[]>;

export interface ValidationErrorDetails {
  fieldErrors?: FieldErrors;
}

export type ApiErrorCode =
  | "VALIDATION_ERROR"
  | "EMAIL_ALREADY_REGISTERED"
  | "RATE_LIMITED"
  | "INTERNAL_ERROR"
  | "INVALID_CREDENTIALS"
  | "UNAUTHENTICATED"
  | "EMAIL_NOT_VERIFIED"
  | "DECK_NAME_NOT_UNIQUE"
  | "NOT_FOUND"
  | "AI_PROVIDER_ERROR"
  | "GENERATION_ALREADY_COMMITTED";

export interface ApiErrorDTO<TCode extends ApiErrorCode = ApiErrorCode, TDetails = unknown> {
  code: TCode;
  message: string;
  details?: TDetails;
}

export interface ApiErrorResponse<
  TCode extends ApiErrorCode = ApiErrorCode,
  TDetails = unknown,
  TMeta extends ApiMetaBase = ApiMetaBase,
> {
  error: ApiErrorDTO<TCode, TDetails>;
  meta: TMeta;
}

// ----------------------------
// Core DTOs (Appendix + used across endpoints)
// ----------------------------

/**
 * Supabase Auth user DTO.
 * DB linkage: `id` uses the same type as FK columns (`decks.user_id`, `ai_generations.user_id`).
 */
export interface UserDTO {
  id: UserId;
  email: string;
  emailVerified: boolean;
}

/**
 * Deck DTO (API camelCase).
 * DB linkage: field types are derived from `public.decks` row.
 */
export interface DeckDTO {
  id: DeckRow["id"];
  name: DeckRow["name"];
  description: DeckRow["description"];
  createdAt: DeckRow["created_at"];
}

/** Deck DTO with computed `cardCount` (returned by list/get/update endpoints). */
export interface DeckSummaryDTO extends DeckDTO {
  cardCount: number;
}

/**
 * Card DTO (API camelCase).
 * DB linkage: field types are derived from `public.cards` row.
 */
export interface CardDTO {
  id: CardRow["id"];
  deckId: CardRow["deck_id"];
  front: CardRow["front"];
  back: CardRow["back"];
  source: CardSource;
  aiGenerationId: CardRow["ai_generation_id"];
  createdAt: CardRow["created_at"];
}

/**
 * AI generation DTO (API camelCase).
 * DB linkage: field types are derived from `public.ai_generations` row.
 */
export interface AiGenerationDTO {
  id: AiGenerationRow["id"];
  deckId: AiGenerationRow["deck_id"];
  createdAt: AiGenerationRow["created_at"];
  committedAt: AiGenerationRow["committed_at"];
}

/**
 * AI suggestion DTO is ephemeral (not stored in DB).
 * DB linkage: `index` uses `ai_suggestions.suggestion_index` type, `front/back` reuse `cards.front/back`.
 */
export interface AiSuggestionDTO {
  index: AiSuggestionRow["suggestion_index"];
  front: CardRow["front"];
  back: CardRow["back"];
}

// ----------------------------
// Auth endpoints - Command Models + response DTOs
// ----------------------------

export interface SignUpCommand {
  email: string;
  password: string;
  emailRedirectTo: string;
}

export interface SignUpResponseData {
  user: UserDTO;
}

export interface SignInCommand {
  email: string;
  password: string;
}

export interface SessionDTO {
  accessToken: string;
  expiresAt: IsoDateString;
}

export interface SignInResponseData {
  session: SessionDTO | null;
  user: UserDTO;
}

export interface SignOutResponseData {
  signedOut: true;
}

export interface MeResponseData {
  user: UserDTO;
}

export interface ResendVerificationCommand {
  email: string;
  emailRedirectTo: string;
}

export interface ResendVerificationResponseData {
  sent: true;
}

export interface ChangePasswordCommand {
  currentPassword: string;
  newPassword: string;
}

export interface ChangePasswordResponseData {
  changed: true;
}

export interface DeleteAccountCommand {
  password: string;
}

export interface DeleteAccountResponseData {
  deleted: true;
}

// ----------------------------
// Decks endpoints - Command Models + response DTOs
// ----------------------------

export interface ListDecksQuery {
  limit?: number;
  cursor?: string;
  sort?: "created_at:desc" | "created_at:asc" | "name:asc" | "name:desc";
  q?: string;
}

export type ListDecksResponseData = DeckSummaryDTO[];

export interface CreateDeckCommand {
  name: DeckRow["name"];
  description?: DeckRow["description"];
}

export type CreateDeckResponseData = DeckDTO;

export type GetDeckResponseData = DeckSummaryDTO;

export interface UpdateDeckCommand {
  name?: DeckRow["name"];
  description?: DeckRow["description"];
}

export type UpdateDeckResponseData = DeckSummaryDTO;

export interface DeleteDeckResponseData {
  deleted: true;
}

// ----------------------------
// Cards endpoints - Command Models + response DTOs
// ----------------------------

export interface ListCardsQuery {
  limit?: number;
  cursor?: string;
  sort?: "created_at:desc" | "created_at:asc";
}

export type ListCardsResponseData = CardDTO[];

export interface CreateCardCommand {
  front: CardRow["front"];
  back: CardRow["back"];
}

export type CreateCardResponseData = CardDTO;

export interface UpdateCardCommand {
  front?: CardRow["front"];
  back?: CardRow["back"];
}

export type UpdateCardResponseData = CardDTO;

export interface DeleteCardResponseData {
  deleted: true;
}

// ----------------------------
// AI generation flow - Command Models + response DTOs
// ----------------------------

export interface CreateAiGenerationCommand {
  text: string;
  deckId: DeckId | null;
}

export interface CreateAiGenerationResponseData {
  generation: AiGenerationDTO;
  suggestions: AiSuggestionDTO[];
}

/**
 * Commit decision is a discriminated union reflecting API rules:
 * - `removed` has no `front/back`
 * - accepted states must carry the final (possibly edited) `front/back`
 *
 * DB linkage:
 * - `index` → `ai_suggestions.suggestion_index`
 * - `finalState` → `public.ai_suggestions.final_state` enum
 * - `front/back` reuse `public.cards` columns (because accepted decisions become saved cards)
 */
export type AiSuggestionDecisionDTO =
  | {
      index: AiSuggestionRow["suggestion_index"];
      finalState: "removed";
    }
  | {
      index: AiSuggestionRow["suggestion_index"];
      finalState: Exclude<AiSuggestionFinalState, "removed">;
      front: CardRow["front"];
      back: CardRow["back"];
    };

export interface CommitAiGenerationCommand {
  deckId: DeckId;
  decisions: AiSuggestionDecisionDTO[];
}

export interface CommitAiGenerationResponseData {
  generation: AiGenerationDTO;
  createdCards: Pick<CardDTO, "id" | "deckId">[];
  counts: {
    acceptedUnchanged: number;
    acceptedEdited: number;
    removed: number;
    savedCards: number;
  };
}

export interface ListAiGenerationsQuery {
  limit?: number;
  cursor?: string;
  committed?: boolean;
  deckId?: DeckId;
  sort?: "created_at:desc" | "created_at:asc";
}

export type ListAiGenerationsResponseData = AiGenerationDTO[];

export interface AiSuggestionFinalStateDTO {
  index: AiSuggestionRow["suggestion_index"];
  finalState: AiSuggestionFinalState;
}

export interface GetAiGenerationResponseData {
  generation: AiGenerationDTO;
  finalStates: AiSuggestionFinalStateDTO[];
}
