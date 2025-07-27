# How to Use `giv` in Your Development Workflow

This guide provides a comprehensive overview of integrating `giv` into your development workflow, including examples of using it with staged changes, working tree modifications, and automating version bumps and changelog updates during releases.

## 📌 Prerequisites

Before using `giv`, ensure the following:

1. **Install Dependencies**:  
   `giv` requires `git` (version 2.25 or newer). Install using:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/giv-cli/giv/main/install.sh | sh
   ```

2. **Initialize Configuration**:  
   Run interactive setup to configure your project:
   ```bash
   giv config
   ```

3. **Set Up API Configuration**:  
   Configure API settings for AI services:
   ```bash
   # For local Ollama
   giv config api.url "http://localhost:11434/v1/chat/completions"
   giv config api.model "devstral"
   giv config api.key "ollama"
   
   # For OpenAI
   giv config api.url "https://api.openai.com/v1/chat/completions"
   giv config api.model "gpt-4o-mini"
   giv config api.key "your_api_key_here"
   ```

## 🔄 Workflow Scenarios

### 1. **Working with Staged Changes**

Use `giv` to generate commit messages, changelogs, or summaries based on **staged changes** (after running `git add`).

#### ✅ Example: Generate Commit Message for Staged Changes

```bash
# Stage your changes
git add .

# Generate commit message based on staged files
giv message --cached

# Or commit directly with generated message
git commit -m "$(giv message --cached)"
```

#### ✅ Example: Generate Changelog for Current Changes

```bash
# Generate changelog for working tree changes
giv changelog

# Generate changelog for staged changes
giv changelog --cached

# Generate changelog for a specific revision range
giv changelog v1.0.0..HEAD
```

#### ✅ Example: Generate Summary for Changes

```bash
# Generate summary for current changes
giv summary

# Generate summary for staged changes
giv summary --cached
```

#### 📌 Notes

- `--staged` analyzes diffs in the index (staged files).
- `--summary` outputs a concise summary of the changes (does not update the changelog).
- `--message` outputs an LLM-generated commit message for the changes.
- You can combine `--summary` and `--message`.

#### 📁 Reference

- See `test_insert_changelog.bats` for how `giv.sh` is used in test scenarios.

### 2. **Working with Unstaged Changes (Working Tree)**

Use `giv` to inspect **unstaged changes** in your working directory (default behavior, or with `--current`).

#### ✅ Example: Generate Changelog for Unstaged Changes

```bash
# Generate changelog based on working tree changes (default)
giv
# Or explicitly:
giv --current
```

#### ✅ Example: Output a Summary or Commit Message for Unstaged Changes

```bash
giv --summary
giv --message
giv --summary --message
```

#### 📌 Notes

- This is ideal for local development before staging changes.
- `--current` is the default if neither `--staged` nor `--all` nor `--from`/`--to` are specified.
- `--summary` and `--message` can be used independently or together.

### 3. **Release Cycle: Changelog Update for a Commit Range**

Automate changelog updates for a specific commit range using `--from` and `--to`.

#### ✅ Example: Generate Changelog for a Commit Range

```bash
# Generate changelog for all changes from v1.0.0 to HEAD
giv --from v1.0.0 --to HEAD
```

#### 📌 Notes

- Use `--all` to include all history from the first commit to HEAD.
- Use `--changelog-file` to specify a custom changelog file.
- Use `--model-provider remote --api-model gpt-4 --api-url ...` to use a remote LLM API.

#### 📁 Reference

- The `test_Version-3a_auto-2ddetect_version_file.log` demonstrates how `giv` auto-detects version files (e.g., `package.json`, `Cargo.toml`).

## 🛠️ Key Options in `giv.sh`

The `giv.sh` script provides several flags and options. Here are key ones:

| Flag/Option             | Description                                                                 |
|-|--|
| `--current`             | Analyze unstaged (working tree) changes (default)                           |
| `--staged`              | Analyze staged changes (index)                                              |
| `--all`                 | Include all history (from first commit to HEAD)                             |
| `--from <rev>`          | Set the starting commit (default: HEAD)                                     |
| `--to <rev>`            | Set the ending commit (default: HEAD^)                                      |
| `--summary`             | Output a summary of the changes to the console                              |
| `--message`             | Output a commit message for the changes to the console                      |
| `--changelog-file <f>`  | Path to changelog file to update (default: ./CHANGELOG.md)                  |
| `--model <model>`       | Specify the local Ollama model to use (default: qwen2.5-coder)              |
| `--model-provider <m>`  | Control how changelog is generated: auto (default), local, remote, none      |
| `--api-model <model>`   | Specify remote API model (overrides --model for remote usage)                |
| `--api-url <url>`       | Specify remote API endpoint URL for changelog generation                    |
| `--prompt-template <f>` | Path to prompt template file (default: ./changelog_prompt.md)               |
| `--update-mode <mode>`  | Section update mode: auto (default), prepend, append, update, none          |
| `--section-name <name>` | Target section name (default: detected version or "Current Changes")        |
| `--version-file <f>`    | File to check for version number changes in each commit                     |
| `--save-prompt`         | Generate prompt file only and do not produce changelog                      |
| `--save-history`        | Do not delete the intermediate git history file                             |
| `--make-prompt-template <f>` | Write the default prompt template to a file                        |
| `--debug`               | Enable debug output                                                         |
| `--help`                | Show help message and exit                                                  |
| `--version`             | Show script version and exit                                                |

## 🧪 Integration with CI/CD

Use `giv` in CI/CD pipelines to automate changelog generation and versioning.

#### ✅ Example: GitHub Actions Workflow

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '16'
      - name: Install dependencies
        run: npm install
      - name: Update changelog for release
        run: giv --from v1.1.0 --to HEAD --changelog-file ./CHANGELOG.md --model-provider remote --api-model gpt-4 --api-url ${{ secrets.GIV_API_URL }}
        env:
          GIV_API_KEY: ${{ secrets.GIV_API_KEY }}
```

#### 📌 Notes

- Ensure the .env file or environment variables are securely stored in your CI/CD environment.
- Use `--summary` or `--message` for previewing changes in CI/CD without modifying files.

## 📚 Troubleshooting and Tips

- **Custom Changelog Templates**:  
  Use `--prompt-template` to specify a custom changelog prompt template.

- **Handling Merge Conflicts**:  
  Manually resolve changelog conflicts if they occur during merges.

- **Debug Mode**:  
  Run `giv --debug` to see detailed logs for debugging.

## 📖 Further Reading

- CHANGELOG.md: Example of .env usage and CI/CD integration.
- test_insert_changelog.bats: How giv.sh is used in test scenarios.
- test_Version-3a_auto-2ddetect_version_file.log: Auto-detection of version files.

By following this guide, you can streamline your workflow with `giv`, ensuring consistent changelogs and versioning across your projects.
