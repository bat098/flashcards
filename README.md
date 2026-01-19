# Fiszki AI (AI Flashcards) — MVP

AI-assisted flashcard creation for spaced repetition learning. The MVP focuses on generating **high-quality flashcard suggestions from pasted English text**, while keeping **full user control** via review, edit, accept, and remove actions.

[![Node](https://img.shields.io/badge/node-22.14.0-339933?logo=node.js&logoColor=white)](#4-getting-started-locally)
[![Astro](https://img.shields.io/badge/astro-5-ff5d01?logo=astro&logoColor=white)](https://astro.build/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](#8-license)

## Table of contents

- [1. Project name](#1-project-name)
- [2. Project description](#2-project-description)
- [3. Tech stack](#3-tech-stack)
- [4. Getting started locally](#4-getting-started-locally)
- [5. Available scripts](#5-available-scripts)
- [6. Project scope](#6-project-scope)
- [7. Project status](#7-project-status)
- [8. License](#8-license)

## 1. Project name

**Fiszki AI (AI Flashcards) — MVP**

## 2. Project description

The MVP goal is to reduce the time it takes to create good flashcards for spaced repetition learning by using AI to generate **10 flashcard proposals** from a pasted text, and then letting the user:

- **Accept** proposals unchanged
- **Edit** front/back and accept after editing
- **Remove** proposals that should not be saved
- **Commit** the accepted proposals to a chosen deck only at the end (no partial saves)

Product docs live in:

- `/.ai/prd.md` — product requirements (MVP scope)
- `/.ai/tech-stack.md` — rationale & risks for the proposed stack

## 3. Tech stack

- **Frontend**
  - **Astro 5** (`astro`)
  - **React 19** (`react`, `react-dom`) for interactive “islands”
  - **TypeScript 5**
  - **Tailwind CSS 4** (`tailwindcss`, `@tailwindcss/vite`)
  - **shadcn/ui** (Radix primitives + utility libs like `class-variance-authority`, `clsx`, `tailwind-merge`)
  - **lucide-react** for icons

- **Backend & database (planned for MVP)**
  - **Supabase** (Auth + Postgres + RLS)
  - Mandatory **email verification** before any product action (create/edit decks/cards, AI generation, study session)

- **AI provider (planned for MVP)**
  - **OpenRouter** via server-side API calls (API keys must never be exposed to the client)

- **Quality tooling**
  - **ESLint** + TypeScript ESLint + Astro/React plugins
  - **Prettier**
  - **Husky** + **lint-staged**

## 4. Getting started locally

### Prerequisites

- **Node.js `22.14.0`** (required; see `.nvmrc`)
- **npm** (ships with Node)

### Install & run

```bash
nvm use
npm install
npm run dev
```

Then open the URL printed by Astro (usually `http://localhost:3000`).

### Optional: environment variables (planned)

This MVP is expected to integrate with Supabase and OpenRouter. When those parts are implemented, you will likely need environment variables (names may change as the code evolves), such as:

  - `SUPABASE_URL`
  - `SUPABASE_KEY`
  - `OPENROUTER_API_KEY`

## 5. Available scripts

From `package.json`:

- **`npm run dev`**: start the dev server
- **`npm run build`**: build for production
- **`npm run preview`**: preview the production build locally
- **`npm run astro`**: run Astro CLI commands
- **`npm run lint`**: run ESLint
- **`npm run lint:fix`**: run ESLint with auto-fixes
- **`npm run format`**: format files with Prettier

## 6. Project scope

### In scope (MVP)

- **Accounts & security**
  - Email + password sign up / sign in / sign out
  - **Email verification required**; unverified users can only see a verification prompt and resend the email
  - Change password and account deletion (also removes user’s decks/cards)
  - Server-side authorization: users can only access their own data (**RLS is the source of truth**)

- **Decks**
  - Create / edit / delete decks
  - Deck list shows name, optional description, and card count
  - Deck details view with card list and actions (add manual card, generate via AI, start study session)

- **Cards (flashcards)**
  - Simple **front/back** format (EN → EN: vocabulary + definitions)
  - CRUD operations with validations (required fields, length limits)

- **AI generation flow**
  - Input: pasted English text up to **10,000 characters**
  - Output: **10** proposed flashcards (`front`, `back`)
  - Review screen supports: accept / edit / remove per proposal
  - Final **commit** saves only accepted proposals to the selected deck
  - **Regenerate** replaces the list and discards all local edits/acceptance/removals (no versioning)
  - Validation: reject malformed AI output (missing `front`/`back`) and enforce field length limits
  - Minimal metrics per generation: generation id, proposal id, final state (`accepted_unchanged`, `accepted_edited`, `removed`), and whether the list was committed

- **Study session (spaced repetition)**
  - Integrate an open-source algorithm library (e.g. **SM-2** or **FSRS**)
  - Per-card scheduling state stored in the database
  - Daily global limit: **50 cards/day** (reviews + new)
  - Queue rules:
    - First: due reviews sorted by increasing due date (most overdue first)
    - Then: new cards by creation order (oldest first) until the limit is reached
  - Session flow: show front → reveal back → grade using **Again / Hard / Good / Easy** → next card
  - Session is **not resumable**; restarting recalculates today’s queue
  - Summary view: totals (X/50), new vs review, grade counts

### Out of scope (explicitly not in MVP)

- Custom advanced SRS algorithm (like Anki/SuperMemo)
- Imports (PDF/DOCX/etc.)
- Sharing decks between users or public links
- Mobile native apps (web only for MVP)
- Tags/categories, advanced search, global stats dashboard
- Automatic “AI quality control” beyond schema + limit validation (user is the QA gate)

### Non-functional requirements (minimum)

- **Accessibility**: basic keyboard support for key forms and review flows
- **Reliability**: clear error messages for network/AI failures and validation issues
- **Privacy**: user data is private; server enforces authorization

## 7. Project status

**Early stage / MVP in progress.**

This repository currently provides the Astro/React/Tailwind foundation (and lint/format tooling). The PRD and tech stack docs define the target MVP features (auth, decks/cards, AI generation, and SRS sessions) that will be implemented next.

## 8. License

**MIT**.

Note: the repo currently doesn’t include a `LICENSE` file. To make the license explicit for GitHub and downstream users, add a `LICENSE` file containing the MIT license text.
