# FaunaWatch — AI Agent Instructions

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
- Mapping: Mapbox

## Essential Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test
dart format .
```

Do not consider a task complete if `flutter analyze` reports errors.

New or changed business logic, ViewModel behavior, repository behavior,
service behavior, or other testable application logic should have
corresponding tests.

Purely visual or documentation-only changes do not require tests unless
existing behavior is affected.

## Code Formatting

Use the standard Dart formatter.

Before considering a code change complete, format modified Dart files with:

    dart format .

Do not manually format Dart code in a way that conflicts with the Dart
formatter.

## Platform Targets

- Android is the primary development and testing platform.
- iOS is a required supported platform.
- Code must not unnecessarily depend on Android-specific behavior.
- When adding plugins or platform capabilities, verify that the dependency
  supports both Android and iOS.
- Platform-specific implementation must be isolated from shared application
  logic.
- Do not remove or disable the `ios/` project because development currently
  occurs on Windows.

## Architecture — Non-Negotiable

Strict MVVM + separation of concerns:

1. **Models** (`lib/data/models/` or feature-local `models/`): Pure Dart
   types/domain logic only. No Flutter widget imports, no direct API/DB
   calls, no side effects.
2. **Services** (`lib/core/services/` or feature-local `services/`):
   Encapsulate external integrations only — AI provider calls, Supabase
   access, device capabilities (location, camera, storage), and
   authentication. Services must not contain UI state or widgets and
   should not contain presentation logic.
3. **ViewModels**: Classes responsible for presentation state and
   presentation-related logic. Riverpod providers/notifiers are used to
   expose and manage ViewModels and their state. ViewModels call the
   Service layer and expose a clean interface to Views. No widget/UI code
   here.
4. **Views**: Flutter widgets. Presentation and user interaction only.
   Never call a Service directly, never contain business logic.

**Repository is optional.** Introduce a Repository sub-layer only for a
feature that genuinely needs one (e.g. local cache + remote sync). Do not
add one by default, and do not introduce one solely to satisfy the
architecture.

### Working style

- Before implementing a feature, briefly state which layer(s) it touches
  and why.
- For a new feature, show the applicable chain:
  Model → Service → ViewModel → View.
- If a Repository is genuinely required, show:
  Model → Service → Repository → ViewModel → View.
- Do not introduce a Repository solely to satisfy the architecture.
- Flag explicitly, before writing code, if a request would require
  breaking this layering (e.g. calling Supabase directly from a widget).
- Keep feature code within its feature directory (`lib/features/<name>/`).
  Do not create large generic folders containing unrelated functionality.
  Do not scaffold every architectural layer folder up front — create them
  as features actually need them.

## AI Provider Integration

FaunaWatch supports Gemini, Groq, and OpenRouter.

Users provide and manage their own AI provider API keys. The mobile
application authenticates directly with the selected AI provider using the
user's own API key.

There are no shared or hardcoded FaunaWatch AI provider keys.

A user's AI API key is runtime user data, not application configuration.

- NEVER store API keys in source code, `.env` files, shared
  preferences/plain-text local storage, Git-tracked configuration, logs,
  or analytics.
- Use platform-backed secure storage (e.g. Keychain/Keystore-backed
  storage) for persistent API keys.
- Never send a user's AI provider API key to the FaunaWatch backend unless
  the architecture is explicitly changed and approved by the team.
- AI provider calls must be made through the Service layer and must never
  be initiated directly from Views or ViewModels.
- Abstract provider implementations behind a common interface so the app
  is not tightly coupled to one provider.
- Provider-specific request formats, models, capabilities, errors, and
  response structures must remain isolated inside their provider
  implementations.
- Do not assume Gemini, Groq, and OpenRouter support identical models,
  request formats, capabilities, or response structures.
- Tests must mock AI provider calls. Never allow `flutter test` or CI to
  make live calls to Gemini, Groq, or OpenRouter.

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

## Documentation

Update this file when introducing significant architectural changes,
new dependencies, or new configuration requirements. Keep it consistent
with the actual implementation — don't let it drift into aspiration.

## Important Project Rule

Do not invent project requirements. If implementation details are
unclear, inspect the repository and existing documentation first, then
follow the clarification protocol above rather than guessing.