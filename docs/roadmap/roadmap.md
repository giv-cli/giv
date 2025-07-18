# Roadmap for giv CLI

## Version 0.4.0
**Focus:** Bug Fixes, Refactoring, and Improved Configuration Management

- **Bug Fixes:**
  - Resolve the `--api-key` parsing issue mentioned in the review.
  - Address edge-case errors in flow control around model invocation and `summarize` vs `dry-run` logic.
- **Refactoring:**
  - Simplify flow control for model invocation to improve maintainability.
  - Modularize the `summarize_target()` and `summarize_commit()` functions for better readability and testing.
- **Configuration Enhancements:**
  - Implement the polished `parse_args()` function from the `giv_folder.md` file.
  - Add `.giv` initialization on first run with default templates and configuration.
  - Ensure proper precedence for configuration sources: CLI args → config file → `.giv/.givrc` → environment variables.
- **Testing:**
  - Increase automated testing coverage for text insertion and token replacement functions.
  - Add unit tests for the new `parse_args()` and `.giv` initialization logic.

## Version 0.5.0
**Focus:** Enhanced LLM Interaction and User Experience

- **LLM Interaction:**
  - Introduce support for additional local models (e.g., Qwen, DevStral, DeepSeek-R1) via Ollama.
  - Add a `--model-mode` option to toggle between local and remote models seamlessly.
  - Optimize prompt construction for smaller models by refining the commit summarization pipeline.
- **User Experience:**
  - Add interactive prompts for missing mandatory fields (e.g., `GIV_MODEL`) during initialization.
  - Improve error messages for invalid configurations or missing dependencies.
  - Add a `--dry-run` mode for all subcommands to preview changes without modifying files.
- **Documentation:**
  - Update the `docs/` folder with detailed usage examples for new features.
  - Add a troubleshooting guide for common issues (e.g., API key errors, model compatibility).

## Version 0.6.0
**Focus:** Advanced Features and Ecosystem Integration

- **New Features:**
  - Add support for generating categorized changelogs (e.g., `Added`, `Fixed`, `Removed`) based on commit tags or keywords.
  - Introduce a `--template-dir` override to allow custom prompt templates for advanced users.
  - Add a `--temperature` flag for fine-tuning LLM output style (e.g., concise vs. verbose).
- **Ecosystem Integration:**
  - Add support for additional version files (e.g., `pyproject.toml`, `composer.json`) to detect version changes.
  - Integrate with CI/CD pipelines to automate changelog and release note generation.
  - Add a `--ci-mode` flag for non-interactive runs in CI environments.
- **Performance Improvements:**
  - Optimize the `summarize_commit()` function to handle large diffs more efficiently.
  - Reduce memory usage during prompt construction by streaming commit summaries.

## Version 0.7.0 and Beyond
**Focus:** Community Feedback and Scalability

- **Community-Driven Features:**
  - Gather feedback from users to prioritize new features and improvements.
  - Add support for additional LLM providers based on user demand.
- **Scalability:**
  - Improve handling of large repositories with thousands of commits.
  - Add caching mechanisms for frequently used prompts and summaries.
- **Advanced Customization:**
  - Allow users to define custom token replacement rules for prompt templates.
  - Add support for multilingual changelogs and release notes.