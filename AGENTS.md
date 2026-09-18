# FaunaWatch — AI Agent Instructions

## Instruction Priority

This file is the canonical source of shared development instructions for
FaunaWatch.

Tool-specific instruction files may reference this file but should not
duplicate or contradict it.

When instructions conflict, follow this priority:

1. Explicit instructions from the human developer for the current task
2. `AGENTS.md`
3. Existing established project conventions
4. Tool-specific agent defaults

Do not modify architectural rules in this file merely to justify an
implementation choice.

## Project Overview

FaunaWatch is a Flutter-based mobile application for an AI-assisted wildlife
reporting and monitoring platform.

Users report wildlife sightings and incidents using photographs and location
data. AI-assisted features analyze submitted images/reports for species
identification, severity assessment, invasive-species detection, validation,
summaries, and safety recommendations.

This repository contains the FaunaWatch mobile application.

## Tech Stack

- Flutter 3.44.1 (stable channel) / Dart 3.12.1
- State management: Riverpod
- Backend: Supabase
- MVVM architecture (Model → Service → ViewModel → View)
- Android and iOS
- AI providers: Google Gemini, Groq, OpenRouter (user-supplied keys)

### Platform Targets

- Android is the primary development and testing platform.
- iOS is a required supported platform.
- Code must not unnecessarily depend on Android-specific behavior.
- When adding plugins or platform capabilities, verify that the dependency
  supports both Android and iOS.
- Platform-specific implementation must be isolated from shared application
  logic.
- Do not remove or disable the `ios/` project because development currently
  occurs on Windows.

## Essential Commands

    flutter pub get                 # install dependencies
    flutter run                     # run on connected device/emulator
    flutter analyze                 # static analysis — must be clean
    flutter test                    # run unit/widget tests
    [FILL IN any custom build/lint scripts, e.g. build_runner, dart format]

Do not consider a task complete if `flutter analyze` reports errors.

New or changed business logic, ViewModel behavior, repository behavior,
service behavior, or other testable application logic should have
corresponding tests.

Purely visual or documentation-only changes do not require tests unless
existing behavior is affected.

## Architecture — Non-Negotiable

Strict MVVM + separation of concerns:

1. **Models** (`lib/data/models/` or feature-local `models/`): Pure Dart
   types/domain logic only. No Flutter widget imports, no direct API/DB
   calls, no side effects.
2. **Services** (`lib/core/services/` or `lib/data/services/`): All
   external integrations live here ONLY — AI provider calls, Supabase
   calls, device capabilities (location, storage), auth. No UI state, no
   widgets. Introduce a Repository sub-layer only for a feature that
   genuinely needs it (e.g. local cache + remote sync) — don't add one by
   default.
3. **ViewModels**: Riverpod providers/notifiers. Hold presentation state,
   call the Service layer, expose a clean interface to Views. No
   widget/UI code here.
4. **Views**: Flutter widgets. Presentation and user interaction only.
   Never call a Service directly, never contain business logic.

### Working style

- Before implementing a feature, briefly state which layer(s) it touches
  and why.
- For a new feature, show the full chain: Model → Service → Repository →
  ViewModel → View.
- Flag explicitly, before writing code, if a request would require
  breaking this layering (e.g. calling Firebase/Supabase from a widget).
- Keep feature code within its feature directory (`lib/features/<name>/`).
  Do not create large generic folders containing unrelated functionality.

## AI Provider Integration

FaunaWatch supports Gemini, Groq, and OpenRouter. Users supply their own
API key; there is no shared/hardcoded key. A user's API key is runtime
user data, not application configuration — treat it accordingly.

- NEVER store API keys in: source code, `.env` files, shared
  preferences/plain-text local storage, Git-tracked configuration, logs,
  or analytics.
- Use platform-backed secure storage (e.g. Keychain/Keystore-backed
  storage) for persistent credentials — not generic local storage.
- Never send a user's AI provider key to FaunaWatch's backend unless the
  architecture explicitly requires it and the team has approved that
  design. Prefer direct provider authentication from the client when
  consistent with the approved architecture.
- Abstract provider implementations behind a common interface so the app
  isn't tightly coupled to one provider.
- **Tests must mock AI provider calls.** Never let `flutter test` or CI
  make live calls to Gemini/Groq/OpenRouter — these are paid, per-key
  rate-limited APIs, and a test run is not a reason to spend someone's
  quota.

## Security

Treat all API keys, tokens, passwords, credentials, and private user data
as secrets. Never commit them. Before adding a new config file, check
whether it could contain sensitive data — use placeholder/example configs
in docs instead of real-shaped values.

## Coding Standards

Idiomatic, null-safe Dart. Use `const` constructors where practical.
Prefer composition over inheritance. Do not introduce a new state
management package or architectural pattern without first confirming it
fits what's listed under Tech Stack above.

Before adding a dependency: check if Flutter/Dart or an existing package
already covers it. Avoid dependencies for trivial functionality.

## Agent Behavior & Guardrails

Before modifying code:
1. Inspect the relevant existing files — don't assume a class/service/
   feature exists without checking.
2. Follow existing conventions; avoid duplicate implementations.
3. Keep changes scoped to the request — no unrelated refactors.

**When a decision would meaningfully affect architecture, or requirements
are unclear:** do not guess and proceed. Stop, leave a clear comment/TODO
at the point of ambiguity explaining the open question, and do not
continue implementing past it. This applies even when running
unattended — pausing means stopping work and flagging it, not silently
picking an interpretation.

**Git:** Work on a feature branch, never push directly to `main`. Do not
merge your own PR. Do not commit API keys, credentials, build artifacts,
or local machine config. Before committing, review `git status` and
`git diff`. Use clear, descriptive commit messages.

### Branch Naming

Use descriptive branches:

- `feature/<name>` — new functionality
- `fix/<name>` — bug fixes
- `refactor/<name>` — internal restructuring
- `docs/<name>` — documentation
- `test/<name>` — test-only changes
- `chore/<name>` — maintenance/tooling

Examples:

feature/wildlife-reporting
feature/ai-provider-settings
fix/location-permission
docs/update-architecture

## Documentation

Update this file when introducing significant architectural changes,
new dependencies, or new configuration requirements. Keep it consistent
with the actual implementation — don't let it drift into aspiration.

## Important Project Rule

Do not invent project requirements. If implementation details are
unclear, inspect the repository and existing documentation first, then
follow the clarification protocol above rather than guessing.