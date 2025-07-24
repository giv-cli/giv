# Subcommand Refactor Guide

## Objective

Refactor the `giv` CLI to simplify the main entry script (`src/giv.sh`) and argument parsing (`src/args.sh`) by focusing only on global options and subcommand delegation. Each subcommand will be implemented as a separate script in the `src/commands/` directory, with specific argument parsing handled within those scripts.

## Overview of Changes

1. **Simplify `src/giv.sh`:**
   - Handle only global options and subcommand delegation.
   - Delegate subcommand execution to scripts in `src/commands/`.

2. **Refactor `src/args.sh`:**
   - Retain only global option parsing.
   - Remove subcommand-specific argument parsing.

3. **Create Subcommand Scripts:**
   - Move subcommand-specific logic and argument parsing to individual scripts in `src/commands/`.

4. **Shared Argument Parsing:**
   - Implement a `parse_document_args` function for shared arguments among document-related subcommands.

5. **Update Metadata Handling:**
   - Refactor `src/project/metadata.sh` to read metadata from `.giv/config` or specialized functions.

6. **Testing and Documentation:**
   - Write unit tests for each subcommand and the main entry script.
   - Update documentation to reflect the new structure.

---

## Step-by-Step Implementation

### 1. Refactor `src/giv.sh`

- **Objective:** Simplify the main entry script to handle only global options and subcommand delegation.

- **Steps:**
  1. Remove subcommand-specific logic from `src/giv.sh`.
  2. Parse global options like `--verbose`, `--update`, `--api-model`, `--api-url`, and `--api-key`.
  3. Identify the subcommand and delegate execution to the corresponding script in `src/commands/`.
  4. Use the following structure for subcommand execution:
     ```bash
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

### 2. Refactor `src/args.sh`

- **Objective:** Retain only global option parsing and remove subcommand-specific argument parsing.

- **Steps:**
  1. Remove logic for parsing subcommand-specific arguments.
  2. Ensure `src/args.sh` sets the `GIV_SUBCMD` variable to the identified subcommand.
  3. Parse and handle global options like `--verbose`, `--update`, `--api-model`, `--api-url`, and `--api-key`.

### 3. Create Subcommand Scripts

- **Objective:** Move subcommand-specific logic and argument parsing to individual scripts in `src/commands/`.

- **Steps:**
  1. For each subcommand (e.g., `config`, `document`, `changelog`, `summary`):
     - Create a corresponding script in `src/commands/` (e.g., `src/commands/config.sh`).
     - Move the specific logic and argument parsing for the subcommand into the script.
     - Ensure each script is self-contained and can handle its own arguments.
  2. Reference `src/commands/config.sh` as an example of how to structure these scripts.

### 4. Implement `parse_document_args` Function

- **Objective:** Create a shared function for parsing arguments common to document-related subcommands.

- **Steps:**
  1. Create a new file `src/commands/document_args.sh`.
  2. Implement the `parse_document_args` function in this file.
  3. Source this file in subcommand scripts like `document.sh`, `changelog.sh`, and `summary.sh`.

### 5. Update `src/project/metadata.sh`

- **Objective:** Refactor metadata handling to read from `.giv/config` or specialized functions.

- **Steps:**
  1. Remove redundant logic for detecting or collecting metadata that is now handled during initialization.
  2. Ensure `metadata.sh` reads metadata from `.giv/config` using `giv config --get <key>` or by sourcing the file.
  3. If specialized logic is needed for a project type, implement it as a function and call it from `metadata.sh`.

### 6. Write Unit Tests

- **Objective:** Ensure the refactored CLI and subcommands work as expected.

- **Steps:**
  1. Write unit tests for each subcommand script to verify correct argument parsing and functionality.
  2. Test the main entry script (`src/giv.sh`) to ensure proper delegation to subcommand scripts.

### 7. Update Documentation

- **Objective:** Reflect the new subcommand structure in the documentation.

- **Steps:**
  1. Update the README to include examples of how to use each subcommand.
  2. Document the new structure and argument parsing in `docs/features/subcommands_refactor.md`.

---

## Example Subcommand Script: `src/commands/config.sh`

```bash
#!/bin/sh
# config.sh: Manage configuration values for giv

case "$1" in
    --list)
        cat "$GIV_CONFIG_FILE"
        ;;
    --get)
        key="$2"
        grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-
        ;;
    --set)
        key="$2"
        value="$3"
        echo "$key=$value" >> "$GIV_CONFIG_FILE"
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
esac
```

---

## Implementation Checklist

- [ ] Refactor `src/giv.sh` to delegate subcommands.
- [ ] Simplify `src/args.sh` to handle only global options.
- [ ] Create individual scripts for each subcommand in `src/commands/`.
- [ ] Implement `parse_document_args` for shared argument parsing.
- [ ] Refactor `src/project/metadata.sh` to read from `.giv/config`.
- [ ] Write unit tests for subcommands and the main entry script.
- [ ] Update documentation to reflect the new structure.
