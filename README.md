**giv** (pronounced “give”) is a POSIX-pure CLI that turns raw Git history into polished commit messages, summaries, changelogs, release notes, and announcements. It follows the [Keep a Changelog][1] spec and [Semantic Versioning][2] rules, and it works with local Ollama models or any OpenAI-compatible. 


## Key Features

* **Subcommand workflow** – `message`, `summary`, `changelog`, `release-notes`, `announcement`, plus `update` & `available-releases` helpers.
* **Flexible AI engine** – Supports both local and remote AI models.
* **Native Git targeting** – Accepts any revision specifier or range defined in *gitrevisions*, and any pathspec (including `:(exclude)` and `!*.md`). ([revision selection][7], [git revisions][5], [gitglossary][8])
* **Version & TODO intelligence** – Detects SemVer bumps and scans only the files you specify for TODOs using regex patterns. ([semver.org][2])
* **Cross-platform** – Runs in Bash, Zsh, Dash, or Ash on Linux, macOS, and Windows (WSL / Git Bash).
* **One-line install & self-update** – Secure `curl | sh` installer; rerun `giv update` anytime for the newest release.


## How it Works

1. **Collect Git data** – revisions, diffs, and optional TODO context. ([git revisions][7], [gitglossary][8])
2. **Detect versions** – matches SemVer strings in files indicated by `--version-file` or via `--version-pattern`. ([semver.org][2])
3. **Build prompt** – merges data with your `--prompt-file`, or the default prompt for that command.
4. **Call the model** – local Ollama or any OpenAI-style endpoint.
5. **Write output** – inserts or updates according to `--output-mode`.


## Examples

```bash
# Initialize giv for a new project (interactive setup)
giv init

# Commit message for working tree
giv message

# Commit staged changes with a generated commit message
git commit -m "$(giv message --cached)"

# Create/update a changelog, scanning TODOs in *.ts files only
giv changelog --todo-files '*.ts' --todo-pattern 'TODO\\(\\w+\\):'

# Create release notes for changes from v1.2.0 to HEAD with a remote endpoint
giv release-notes v1.2.0..HEAD \
    --api-model some-new-model \
    --api-url https://api.example.com/v1/chat/completions

# Configure API settings using dot notation
giv config api.url "https://api.openai.com/v1/chat/completions"
giv config api.model "gpt-4o"
giv config api.key "your-api-key"

# Configure project metadata
giv config project.title "My Project"
giv config project.description "A CLI tool for managing projects"
giv config project.url "https://github.com/user/project"

# List all configuration values
giv config list

# Get specific configuration values
giv config get api.url
giv config api.url  # shorthand syntax

# Remove configuration values
giv config unset api.key
```


## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/giv-cli/giv/main/install.sh | sh
```

The script downloads the latest binary links it in `$PATH`

### Requirements

* POSIX-compliant shell (Bash, Zsh, Dash, Ash)
* curl
* Git ≥ 2.25 ([git-scm.com][3])
* *(Optional)* Ollama for offline LLMs ([github.com][6])


## Usage Overview

```text
giv <subcommand> [revision] [pathspec] [OPTIONS]
```

## Subcommands

| Subcommand            | Action                               |
| --------------------- | ------------------------------------ |
| `message` *(default)* | Draft an AI commit message           |
| `summary`             | Human-readable summary of changes    |
| `changelog`           | Create or update `CHANGELOG.md`      |
| `release-notes`       | Longer notes for a tagged release    |
| `announcement`        | Marketing-style release announcement |
| `document`            | Generate custom content using your own prompt template |
| `config`              | Manage configuration values          |
| `available-releases`  | List script versions                 |
| `update`              | Self-update giv                      |


## Revision & Path Selection

| Element        | Meaning                                                                                                                                                                           |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`revision`** | Any Git *revision* or *revision-range* (`HEAD`, `v1.2.3`, `abc123`, `HEAD~2..HEAD`, `origin/main...HEAD`, `--cached`, `--current`). ([revision selection][7], [git revisions][5]) |
| **`pathspec`** | Standard Git *pathspec* to narrow scope—supports magic prefixes, negation (`!` or `:(exclude)`), and case-insensitive `:(icase)`. ([git pathspec][12], [gitglossary][8])          |


## Option Groups

### General

| Flag                 | Description                     |
| -------------------- | ------------------------------- |
| `-h`, `--help`       | Show help and exit              |
| `-v`, `--version`    | Show giv version                |
| `--verbose`          | Debug / trace output            |
| `--dry-run`          | Preview only; write nothing     |
| `--config-file PATH` | Shell config sourced before run |

### Output Behaviour

| Flag                    | Description                                      |
| ----------------------- | ------------------------------------------------ |
| `--output-mode MODE`    | `auto`, `prepend`, `append`, `update`, `none`    |
| `--output-version NAME` | Overrides section header / tag                   |
| `--output-file PATH`    | Destination file (default depends on subcommand) |
| `--prompt-file PATH`    | Markdown prompt template to use                  |

### Diff & Content Filters

| Flag                      | Description                                            |
| ------------------------- | ------------------------------------------------------ |
| `--todo-files PATHSPEC`   | Pathspec that marks files to scan for TODOs            |
| `--todo-pattern REGEX`    | Regex evaluated inside files matched by `--todo-files` |
| `--version-file PATHSPEC` | Pathspec of file(s) to inspect for version bumps       |
| `--version-pattern REGEX` | Custom regex that identifies version strings           |

### AI / Model

| Flag                | Description                                 |
| ------------------- | ------------------------------------------- |
| `--model MODEL`     | Local Ollama model name                     |
| `--api-model MODEL` | Remote model when `--model-mode remote`     |
| `--api-url URL`     | Remote API endpoint                         |


## Environment Variables

| Variable              | Purpose                                            |
| --------------------- | -------------------------------------------------- |
| `GIV_API_KEY`         | API key for remote model                           |
| `GIV_API_URL`         | Remote API endpoint URL                            |
| `GIV_API_MODEL`       | Remote model name                                  |
| `GIV_PROJECT_TITLE`   | Project name                                       |
| `GIV_PROJECT_DESCRIPTION` | Project description                            |
| `GIV_PROJECT_URL`     | Project URL                                        |
| `GIV_CONFIG_FILE`     | Path to configuration file                         |

**Configuration Management:**

giv uses a Git-style configuration system. You can manage settings with:

```bash
# Interactive setup (creates .giv/config and prompts for values)
giv init

# List all configuration values
giv config list

# Get a specific value
giv config get api.url
giv config api.url  # shorthand syntax

# Set a configuration value
giv config set api.url "https://api.openai.com/v1/chat/completions"
giv config api.url "https://api.openai.com/v1/chat/completions"  # shorthand

# Remove a configuration value
giv config unset api.url
```

Configuration is stored in `.giv/config` in your project root and can be overridden with environment variables or command-line flags. The hierarchy is:

1. Command-line arguments (highest priority)
2. Environment variables  
3. `.giv/config` file
4. Default values (lowest priority)

## License

CC-BY. If **giv** helps you *give* better releases, please ⭐ the repo and spread the word!

## Contributing

We welcome contributions from everyone! If you'd like to contribute, please follow these steps:

1. **Clone the repository and update submodules:**
   ```bash
   git clone https://github.com/giv-cli/giv.git
   cd giv
   git submodule update --init --recursive
   ```

2. **Create a new branch for your changes:**
   ```bash
   git checkout -b my-feature-branch
   ```

3. **Make your changes and commit them:**
   ```bash
   # Make changes...

   # Verify all tests pass
   bats tests/*.bats
   
   git add .
   git commit -m "$(giv message --staged)"
   ```

4. **Push your changes to GitHub:**
   ```bash
   git push origin my-feature-branch
   ```

5. **Create a pull request on GitHub.**

Please ensure that your contributions adhere to the existing code style and include appropriate tests if necessary.

[1]: https://keepachangelog.com/en/1.1.0/ "Keep a Changelog"
[2]: https://semver.org/ "Semantic Versioning 2.0.0 | Semantic Versioning"
[3]: https://git-scm.com/downloads "Git Downloads"
[5]: https://git-scm.com/docs/gitrevisions "gitrevisions Documentation - Git"
[6]: https://github.com/ollama/ollama "ollama"
[7]: https://git-scm.com/book/en/v2/Git-Tools-Revision-Selection "7.1 Git Tools - Revision Selection"
[8]: https://git-scm.com/docs/gitglossary "gitglossary Documentation - Git"
[9]: https://git-scm.com/docs/gitignore "gitignore Documentation - Git"
[12]: https://git-scm.com/docs/git-add/2.37.3 "git add - pathspec-from-file=<file>"
