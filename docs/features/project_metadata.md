Lets implement this feature:


# Simplified Project-Level Metadata Architecture for giv

## Objective

Make project metadata collection simple, reliable, and portable by:

1. Detecting project type and setting all relevant metadata during initialization (in `initialize_metadata` and `detect_project_type`).
2. Storing all metadata in `.giv/config` using the `giv config` subcommand.
3. Allowing user overrides and custom metadata via the same config mechanism.
4. Having `project/metadata.sh` simply read metadata from config or call specialized functions for each project type if needed.

This approach eliminates the need for a complex provider registry/orchestration. Instead, project type and metadata are set up front, and all prompt logic can rely on a single, consistent metadata source.



## High-Level Architecture Changes

1. **Initialization Phase:**
   - During `initialize_metadata`, the script calls `detect_project_type` to determine the project type and set all relevant metadata keys (type, version file, version pattern, etc.) using `giv config`.
   - The user is prompted for any missing or custom values, which are also set in `.giv/config`.

2. **Metadata Storage:**
   - All metadata is stored in `.giv/config` in .env format, managed by the `giv config` subcommand.
   - User overrides and custom metadata are handled the same way.

3. **Metadata Access:**
   - `project/metadata.sh` simply reads metadata from `.giv/config` (using `giv config --get <key>` or by sourcing the file).
   - If specialized logic is needed for a project type, it can be implemented as a function and called by `metadata.sh`.

4. **Prompt Integration:**
   - Prompt logic (e.g., in `llm.sh`) reads metadata from the config/cache and supports token replacement as before.



## Provider Logic (Refactored)

Instead of a registry of provider scripts, project type detection and metadata collection are handled directly in `detect_project_type` and `initialize_metadata`. For each known project type, the script sets the appropriate metadata keys in `.giv/config`.

If a project type requires more advanced metadata extraction, a specialized function can be called during initialization or by `metadata.sh` as needed.



## Directory Layout

project/
  metadata.sh # reads metadata from config or calls specialized functions
.giv/
  cache/
    project_metadata.env
  config # all metadata and overrides


done

## Simplified Metadata Flow

1. **Initialization:**
   - `initialize_metadata` calls `detect_project_type`, which sets all relevant metadata keys in `.giv/config` using `giv config`.
   - User is prompted for any missing values.

2. **Metadata Access:**
   - `project/metadata.sh` reads metadata from `.giv/config` (using `giv config --get <key>` or by sourcing the file).
   - If needed, calls specialized functions for additional metadata extraction.

3. **Export:**
   - Metadata is exported to the shell environment for use by prompt logic and other scripts.


title=My Project
author=Jane Doe
latest\_version=1.2.3
repository\_url=https://github.com/org/repo.git

## Cache Format

project_metadata.env: simple KEY=value lines, generated from `.giv/config` and any additional logic.

Example project_metadata.env:

GIV_METADATA_TITLE="My Project"
GIV_METADATA_AUTHOR="Jane Doe"
GIV_METADATA_LATEST_VERSION="1.2.3"
GIV_METADATA_REPOSITORY_URL="https://github.com/org/repo.git"


Prompt Token Usage

Templates can use tokens like:

Project: [title] (v[latest_version])
Home: [url]
Repo: [repository_url]
Desc: [description]
License: [license]



## Configuration (.giv/config)

All metadata keys are managed using the `giv config` subcommand, which stores them in `.giv/config` in .env format (e.g., `GIV_PROJECT_TYPE=auto`).

Example usage:

```sh
giv config project.type auto
giv config project.metadata_file metadata.env
giv config project.metadata_extra "owner.team=platform\ntier=gold"
```

This will result in a `.giv/config` file like:

```
GIV_PROJECT_TYPE="auto"
GIV_PROJECT_METADATA_FILE="metadata.env"
GIV_PROJECT_METADATA_EXTRA="owner.team=platform\ntier=gold"
```

---

Testing & Validation Checklist

\[ \] Providers detect correctly in mixed-type repos

\[ \] Keys include title, url, description, repository\_url, latest\_version

\[ \] Overrides apply with correct precedence

\[ \] Cache files (.env) generate and load properly

\[ \] Prompt tokens replace as expected

\[ \] POSIX shell lint (shellcheck -s sh)

\[ \] --refresh-metadata flag forces reload

---


## Implementation Checklist

- [ ] Refactor initialization to set all metadata in `.giv/config` using `giv config` (in `initialize_metadata` and `detect_project_type`).
- [ ] Remove provider registry/orchestration logic; handle all detection and metadata setting up front.
- [ ] Update `project/metadata.sh` to read from config or call specialized functions as needed.
- [ ] Update prompt logic to use the new metadata flow.
- [ ] Add --refresh-metadata support.
- [ ] Write Bats tests for detection, caching, overrides.
- [ ] Document usage in README.
