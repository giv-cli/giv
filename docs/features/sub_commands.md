# Subcommand Refactor

We need to refactor the entry script [src/giv.sh] and the argument parsing [src/args.sh] 
and simplify it by only focusing on parsing the subcommand and truly global options like 
--verbose, --update, --api-model, --api-url, --api-key

Each subcommand will become it's own script inside the src/commands dir. Reference how src/commands/config.sh is used and implemented.

We can then move the specific argument parsing into each commands script. See how src/commands/config.sh handles it's specifc arguments not related to the document or other document wrapper subcommands such as announcement.

The main entry point should look something like this:
```
    ensure_giv_dir_init
    initialize_metadata
    portable_mktemp_dir
    parse_args "$@"
    metadata_init

if [ -f "${GIV_LIB_DIR}/commands/${GIV_SUBCMD}.sh" ]; then
    ensure_giv_dir_init
    "${GIV_LIB_DIR}/commands/${GIV_SUBCMD}.sh" "$@"
    exit 0
fi
```

We can move all of that arg parsing for these arguments to a parse_document_args function that can be used by the src/commands/document.sh, src/commands/changelog.sh, src/commands/summary.sh scripts.

```
Revision & Path Selection (what to read)
  (positional) revision   Git revision or range
  (positional) pathspec   Git pathspec filter

Diff & Content Filters (what to keep)
  --todo-files PATHSPEC   Pathspec for files to scan for TODOs
  --todo-pattern REGEX    Regex to match TODO lines
  --version-file PATHSPEC Pathspec of file(s) to inspect for version bumps
  --version-pattern REGEX Custom regex to identify version strings

Output Behavior (where to write)
  --output-mode MODE     auto, prepend, append, update, none
  --output-version NAME  Override section header/tag name
  --output-file PATH     Destination file (defaults per subcommand)
  --prompt-file PATH     Markdown prompt template to use (required for 'document')

---

## Detailed Implementation Plan

### Objective
Refactor the `giv` CLI to simplify the main entry script (`src/giv.sh`) and argument parsing (`src/args.sh`) by focusing only on global options and subcommand delegation. Each subcommand will be implemented as a separate script in the `src/commands/` directory, with specific argument parsing handled within those scripts.

### Steps to Implement

1. **Refactor `src/giv.sh` to Delegate Subcommands**
   - Update `src/giv.sh` to:
     - Parse global options like `--verbose`, `--update`, `--api-model`, `--api-url`, and `--api-key`.
     - Identify the subcommand and delegate execution to the corresponding script in `src/commands/`.
     - Use the following structure for subcommand execution:
       ```bash
       ensure_giv_dir_init
       initialize_metadata
       portable_mktemp_dir
       parse_args "$@"
       metadata_init

       if [ -f "${GIV_LIB_DIR}/commands/${GIV_SUBCMD}.sh" ]; then
           "${GIV_LIB_DIR}/commands/${GIV_SUBCMD}.sh" "$@"
           exit 0
       fi
       ```

2. **Move Subcommand Logic to `src/commands/`**
   - For each subcommand (e.g., `config`, `document`, `changelog`, `summary`):
     - Create a corresponding script in `src/commands/` (e.g., `src/commands/config.sh`).
     - Move the specific logic and argument parsing for the subcommand into the script.
     - Ensure each script is self-contained and can handle its own arguments.

3. **Simplify `src/args.sh`**
   - Remove subcommand-specific argument parsing from `src/args.sh`.
   - Retain only global option parsing (e.g., `--verbose`, `--update`, `--api-model`, `--api-url`, `--api-key`).
   - Ensure `src/args.sh` sets the `GIV_SUBCMD` variable to the identified subcommand.

4. **Implement `parse_document_args` Function**
   - Create a `parse_document_args` function to handle shared arguments for document-related subcommands (e.g., `document`, `changelog`, `summary`).
   - Move this function to a shared library file (e.g., `src/commands/document_args.sh`).
   - Source this file in the relevant subcommand scripts.

5. **Update `src/project/metadata.sh`**
   - Ensure `metadata.sh` reads metadata from `.giv/config` or specialized functions for each project type.
   - Remove any redundant logic for detecting or collecting metadata that is now handled during initialization.

6. **Test Each Subcommand**
   - Write unit tests for each subcommand script to ensure correct argument parsing and functionality.
   - Test the main entry script (`src/giv.sh`) to verify proper delegation to subcommand scripts.

7. **Update Documentation**
   - Update the README and other documentation to reflect the new subcommand structure.
   - Provide examples of how to use each subcommand.

### Specific Changes

#### `src/giv.sh`
- Simplify to only handle global options and subcommand delegation.
- Remove subcommand-specific logic.

#### `src/args.sh`
- Retain only global option parsing.
- Remove subcommand-specific argument parsing.

#### `src/commands/`
- Create a script for each subcommand (e.g., `config.sh`, `document.sh`, `changelog.sh`, `summary.sh`).
- Move subcommand-specific logic and argument parsing into these scripts.
- Logic is currently in src/commands.sh

#### `src/project/metadata.sh`
- Refactor to read metadata from `.giv/config` or specialized functions.
- Remove redundant detection/collection logic.

#### Tests
- Write unit tests for each subcommand script.
- Test the main entry script for proper delegation.

#### Documentation
- Update the README and other documentation to reflect the new structure.
- Provide usage examples for each subcommand.

### Expected Outcome
- Simplified and modular codebase.
- Easier maintenance and testing.
- src/commands scripts should be callable directly and easily tested with bats
- Clear separation of global options and subcommand-specific logic.
- Reduced complexity for getting version information at runtime based on project type
    - This includes parsing versions from git command output