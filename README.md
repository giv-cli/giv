**giv** (pronounced “give”) is a POSIX-pure CLI that turns raw Git history into polished commit messages, summaries, changelogs, release notes, and announcements.  It follows the \[Keep a Changelog] spec and Semantic Versioning rules, and it works equally well with local Ollama models or any OpenAI-compatible endpoint—no Python, Node, or Docker required. ([keepachangelog.com][1], [semver.org][2], [github.com][3], [platform.openai.com][4])

---

## Key Features

* **Subcommand workflow** – `message`, `summary`, `changelog`, `release-notes`, `announcement`, plus `update` & `available-releases` helpers. ([git-scm.com][5])
* **Flexible AI engine** – Offline with Ollama or remote via Chat-Completions API, switchable through `--model-mode`. ([github.com][6], [platform.openai.com][4])
* **Native Git targeting** – Accepts any revision specifier or range defined in *gitrevisions*, and any pathspec (including `:(exclude)` and `!*.md`). ([git-scm.com][7], [git-scm.com][5], [git-scm.com][8])
* **Version & TODO intelligence** – Detects SemVer bumps and scans only the files you specify for TODOs using regex patterns. ([semver.org][2], [git-scm.com][9])
* **Zero-dependency, cross-platform** – Runs in Bash, Zsh, Dash, or Ash on Linux, macOS, and Windows (WSL / Git Bash). ([platform.openai.com][10])
* **One-line install & self-update** – Secure `curl | sh` installer; rerun `giv --update` anytime for the newest release. ([curl.se][11])

---

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/itlackey/giv/main/install.sh | sh
```

The script downloads the latest binary, confirms before writing to `$PATH`, and prints a quick-start cheat-sheet. ([curl.se][11])

---

## Usage Overview

```text
giv <subcommand> [revision] [pathspec] [OPTIONS]
```

| Element        | Meaning                                                                                                                                                                  |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **`revision`** | Any Git *revision* or *revision-range* (`HEAD`, `v1.2.3`, `abc123`, `HEAD~2..HEAD`, `origin/main...HEAD`, `--cached`, `--current`). ([git-scm.com][7], [git-scm.com][5]) |
| **`pathspec`** | Standard Git *pathspec* to narrow scope—supports magic prefixes, negation (`!` or `:(exclude)`), and case-insensitive `:(icase)`. ([git-scm.com][8], [git-scm.com][12])  |

---

## Option Groups

### 1  General

| Flag                 | Description                     |
| -------------------- | ------------------------------- |
| `-h`, `--help`       | Show help and exit              |
| `-v`, `--version`    | Show giv version                |
| `--verbose`          | Debug / trace output            |
| `--dry-run`          | Preview only; write nothing     |
| `--config-file PATH` | Shell config sourced before run |

### 2  Revision & Path Selection (*what to read*)

| Flag                      | Description           |
| ------------------------- | --------------------- |
| *(positional)* `revision` | Git revision or range |
| *(positional)* `pathspec` | Git pathspec filter   |

### 3  Diff & Content Filters (*what to keep*)

| Flag                      | Description                                            |
| ------------------------- | ------------------------------------------------------ |
| `--todo-files PATHSPEC`   | Pathspec that marks files to scan for TODOs            |
| `--todo-pattern REGEX`    | Regex evaluated inside files matched by `--todo-files` |
| `--version-file PATHSPEC` | Pathspec of file(s) to inspect for version bumps       |
| `--version-pattern REGEX` | Custom regex that identifies version strings           |

### 4  AI / Model (*how to think*)

| Flag                | Description                                 |
| ------------------- | ------------------------------------------- |
| `--model MODEL`     | Local Ollama model name                     |
| `--model-mode MODE` | `auto` (default), `local`, `remote`, `none` |
| `--api-model MODEL` | Remote model when `--model-mode remote`     |
| `--api-url URL`     | Remote API endpoint                         |

### 5  Output Behaviour (*where to write*)

| Flag                    | Description                                      |
| ----------------------- | ------------------------------------------------ |
| `--output-mode MODE`    | `auto`, `prepend`, `append`, `update`, `none`    |
| `--output-version NAME` | Overrides section header / tag                   |
| `--output-file PATH`    | Destination file (default depends on subcommand) |
| `--prompt-file PATH`    | Markdown prompt template to use                  |

### 6  Maintenance Subcommands

`available-releases` · `update`

---

## Environment Variables

| Variable         | Purpose                                            |
| ---------------- | -------------------------------------------------- |
| `GIV_API_KEY`    | API key for remote model                           |
| `GIV_API_URL`    | Endpoint default if `--api-url` is omitted         |
| `GIV_MODEL`      | Default local model                                |
| `GIV_MODEL_MODE` | `auto`, `local`, `remote`, `none` (overrides flag) |

---

## Subcommands

| Subcommand            | Action                               |
| --------------------- | ------------------------------------ |
| `message` *(default)* | Draft an AI commit message           |
| `summary`             | Human-readable summary of changes    |
| `changelog`           | Create or update `CHANGELOG.md`      |
| `release-notes`       | Longer notes for a tagged release    |
| `announcement`        | Marketing-style release announcement |
| `available-releases`  | List script versions                 |
| `update`              | Self-update giv                      |

---

## Examples

```bash
# Commit message for last 3 commits affecting only src/
giv message HEAD~3..HEAD src/

# Summary plus changelog, scanning TODOs in *.ts files only
giv changelog --todo-files '*.ts' --todo-pattern 'TODO\\(\\w+\\):'

# Release notes from v1.2.0 to HEAD with a remote endpoint
giv release-notes v1.2.0..HEAD \
    --model-mode remote \
    --api-model gpt-4o \
    --api-url https://api.example.com/v1/chat/completions
```

---

## How it Works

1. **Collect Git data** – revisions, diffs, and optional TODO context. ([git-scm.com][7], [git-scm.com][8])
2. **Detect versions** – matches SemVer strings in files indicated by `--version-file` or via `--version-pattern`. ([semver.org][2])
3. **Build prompt** – merges data with your `--prompt-file`, following Keep-a-Changelog guidelines. ([keepachangelog.com][1])
4. **Call the model** – local Ollama or any OpenAI-style endpoint. ([github.com][6], [platform.openai.com][4])
5. **Write output** – inserts or updates according to `--output-mode`.

---

## Requirements

* Git ≥ 2.25 ([git-scm.com][5])
* curl
* POSIX-compliant shell (Bash, Zsh, Dash, Ash) ([platform.openai.com][10])
* *(Optional)* Ollama for offline LLMs ([github.com][6])

---

## License

CC-BY. If **giv** helps you *give* better releases, please ⭐ the repo and spread the word!

[1]: https://keepachangelog.com/en/1.1.0/?utm_source=chatgpt.com "Keep a Changelog"
[2]: https://semver.org/?utm_source=chatgpt.com "Semantic Versioning 2.0.0 | Semantic Versioning"
[3]: https://github.com/taketwo/llm-ollama?utm_source=chatgpt.com "LLM plugin providing access to models running on an Ollama server"
[4]: https://platform.openai.com/?utm_source=chatgpt.com "OpenAI Platform"
[5]: https://git-scm.com/docs/gitrevisions?utm_source=chatgpt.com "gitrevisions Documentation - Git"
[6]: https://github.com/ollama/ollama?utm_source=chatgpt.com "ollama/ollama: Get up and running with Llama 3.3, DeepSeek-R1 ..."
[7]: https://git-scm.com/book/en/v2/Git-Tools-Revision-Selection?utm_source=chatgpt.com "7.1 Git Tools - Revision Selection"
[8]: https://git-scm.com/docs/gitglossary?utm_source=chatgpt.com "gitglossary Documentation - Git"
[9]: https://git-scm.com/docs/gitignore?utm_source=chatgpt.com "gitignore Documentation - Git"
[10]: https://platform.openai.com/docs/api-reference/chat?utm_source=chatgpt.com "com/docs/api-reference/chat - OpenAI Platform"
[11]: https://curl.se/docs/httpscripting.html?utm_source=chatgpt.com "The Art Of Scripting HTTP Requests Using Curl"
[12]: https://git-scm.com/docs/git-add/2.37.3?utm_source=chatgpt.com "git add - pathspec-from-file=<file>"
