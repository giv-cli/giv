# Roadmap for giv CLI

## Version 0.4.0 (Month 1) - Core Stabilization & Init
- **Bug Fixes & Refactoring:**
  - Resolve `--api-key` parsing edge cases.
  - Split `summarize_target()` and `summarize_commit()` into testable modules.
- **`.giv` Initialization:**
  - `giv init` scaffolds a `.giv/` folder with default templates.
  - Enforce CLI args → config file → `.giv/config` → environment‐variable precedence.
- **Project Type Detection:**
  - Introduce `--project-type` flag to detect project metadata and version files (`package.json`, `pyproject.toml`, etc.).
  - Support custom project types with user-specified version file, metadata locations, and parsing patterns.
- **Testing & Coverage:**
  - Add unit tests for `parse_args()`, `.giv` initialization, token replacement, and text insertion.
- **Git Metadata:**
  - Surface `git config user.name` in outputs and inject a date token into summaries.
- **Packaging Validation:**
  - Fix Docker, Flatpak, and Snap build issues.
- **Optional-Dependency Detection:**
  - Warn if Glow, GitHub CLI, or Ollama are missing.
  - Document `GIV_USE_GLOW`, `GIV_USE_GITHUB_CLI`, and `GIV_USE_OLLAMA` environment flags.

## Version 0.5.0 (Month 2) - Release Automation & UX Enhancements
- **Release Tooling:**
  - `giv release` to bump versions, build packages, and draft GitHub/GitLab release notes.
- **Dry-Run Mode:**
  - Implement `--dry-run` across all subcommands to preview changes without writing files.
- **Interactive Mode (Optional):**
  - Add an `--interactive` flag to review, confirm, or regenerate model output before saving.

## Version 0.6.0 (Month 3) - Changelogs & Advanced Post-Processing
- **Categorized Changelogs:**
  - Auto-generate `Added` / `Fixed` / `Removed` sections via commit prefixes or keywords.
- **Advanced Post-Processing:**
  - Apply templates or validation steps to ensure outputs conform to specified formats before saving.

## Version 0.7.0 (Month 4) - Feedback & Governance
- **Feedback Loop:**
  - `giv feedback` to collect user comments and opt-in telemetry for usage insights.
- **Configurable Tokens:**
  - Support user-defined token-replacement rules in `.giv/config`.
- **Governance:**
  - Finalize `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`.
  - Expand API docs with advanced usage examples.

## Version 0.8.0 (Month 5) - Documentation Automation
- **README Generator:**
  - Auto-generate or update `README.md` based on project metadata and recent changes.
- **Changelog Linter:**
  - Validate changelogs against a standard format (e.g., Keep a Changelog).

## Version 0.9.0 (Month 6) - Contribution & License Management + Shell Completions
- **Contribution Guide:**
  - Generate or update `CONTRIBUTING.md` with project-specific guidelines.
- **Code of Conduct:**
  - Auto-create `CODE_OF_CONDUCT.md` aligned with project values.
- **License File Generator:**
  - Generate or update `LICENSE` based on chosen license and project details.
- **Shell Completions:**
  - Provide Bash, Zsh, and Fish completion scripts.

## Version 1.0.0 - Comprehensive Developer Tools
- **API Documentation:**
  - Integrate with Swagger, JSDoc, or similar to generate API docs from source-code comments.
- **Release Notes:**
  - Auto-generate release notes from commit messages, PR descriptions, and changelogs.

## Future (Version 1.1.0) - Semantic Chat & Help Search
- **Conversational Interface:**
  - `giv chat-code` and `giv chat-todos` for semantic browsing of commits and TODOs.
- **Help Search:**
  - `giv help "<query>"`, powered by the Milvious vector index for semantic command guidance.
