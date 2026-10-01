## Agent skills

### Issue tracker

Issues are tracked in this repo's GitHub Issues, using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five default label names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one root `CONTEXT.md` plus `docs/adr/`. See `docs/agents/domain.md`.

## Project conventions

These apply to this repo instead of the global HubSpot/Node conventions.

- **What this is:** scoop (always lowercase; formerly Text Grab), a macOS menu bar app (hotkey → drag-select → on-device OCR → clipboard). Spec: `docs/superpowers/specs/2026-10-01-text-grab-design.md`.
- **Language:** Swift 6, strict concurrency. SwiftPM only; no Xcode project. Building needs **Xcode installed** (free; SwiftUI/Swift Testing macros don't ship with the command line tools alone), but you never open it.
- **Build / test:** `swift build`, `swift test`. Bundle the app: `scripts/bundle.sh` → `dist/scoop.app`.
- **Format:** `swift format --in-place --recursive Package.swift Sources Tests` before committing; CI runs `swift format lint --strict`.
- **Tests:** Swift Testing. Every new logic unit in `TextGrabCore` gets tests.
- **Git:** all changes via PR; `main` is protected and requires CI.
- **Never:** network calls, telemetry, or keeping screenshots in the app; secrets or signing material in the repo.
