# Changelog

All notable changes to the Avila Tek Skill Pack are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [2.7.0] — 2026-06-08

Dev-skill refactor for reuse, SOLID, and token discipline (lint-first). See `docs/proposals/2026-06-08-dev-skills-refactor.md`.

### Added
- **Reuse Scan gate** in `/build` (`dev-incremental-implementation`): mandatory search-before-write for helpers/utils/validators, with an adopt/extend/promote/build decision matrix and an evidence requirement.
- **Shared inventory** (`docs/shared-inventory.md`): format and regeneration wiring defined in `dev-context-engineering` and `dev-harness-eslint` — a per-session memory surface to stop cross-story duplication.
- **Lint rule recipes** in `dev-harness-eslint`: `eslint-plugin-boundaries` (layer + cross-feature), `max-lines`/`max-lines-per-function`/`max-depth`, jsdoc-on-shared-exports, default file-size budgets, and per-stack equivalents for Go/Flutter/Spring Boot. Warn-first rollout for existing repos.
- **Clean Step Checklist** in the build increment cycle, referencing the `dev-code-simplification` thresholds.

### Changed
- **Promotion rule:** pure technical helpers now go to `shared/`/`packages/` on first write; UI/domain code stays colocated until a 2nd feature needs it.
- **Code review** (`dev-code-review-and-quality`): architecture axis now cites boundary lint and the shared inventory; added size-budget and reinvention checklist items.
- **Comments policy:** one-line doc comments now required on `shared/`/`packages/` public exports (feeds the inventory + discoverability); feature-local code keeps the "why, not what" default.
- **Progressive Required Reading** across all stack profiles (`stacks/*/STACK.md`): small edits load only the lightest base doc; full base tier loads only when creating a module or crossing a layer.

### Fixed
- Resolved the contradiction in `dev-using-agent-skills` that claimed skills "do not defer to `agent_docs` at runtime" while every `STACK.md` instructs reading them. Documented the real `STACK.md → agent_docs → references` model.
- Aligned plugin version across `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and the Codex `.codex-plugin/plugin.json` (were drifted at 2.7.0 / 2.6.0 / 2.6.0).

## [2.6.0]

- Baseline prior to the dev-skill refactor.
