# TODOs

## Git Command Robustness:
The use of `git diff` and `git rev-list` assumes the repository is in a clean state. If the user runs giv inside a shallow clone or with unusual ref names, some commands could fail.

The script does check `git rev-parse --is-inside-work-tree` early to ensure you’re in a git repo.

One scenario: very large diffs. Using `--compact-summary` and unified=3 limits output size, but if a commit touched 500 files, the diffstat could still be long.

It might be worth limiting or truncating extremely large diffs before feeding to the LLM summary (perhaps summarizing the diffstat itself). This is more a potential enhancement than a bug; currently, a huge commit might risk hitting token limits for summarization. The code doesn’t explicitly guard against that beyond the diff settings.

In practice, this might rarely be an issue, but it’s good to document.

## Environment Variable Confusion:
There are both config file `.env` loading and environment variables like `GIV_MODEL`, `GIV_API_URL`, etc. The code merges these by preferring CLI args, then env vars, then defaults.

One thing to double-check: if the user sets `GIV_MODEL_MODE=none` (or uses `--model-mode none`), the script sets dry_run=true for generation but still goes through summarization unless explicitly handled.

Actually, in generate_response, if mode is "none", it doesn’t have a case and will default to local which tries Ollama (not desired). There is a check setting model_mode="none" will skip model usage and treat it effectively as dry-run.

This area could be refactored to make the logic clearer: e.g. a single flag that indicates “no model calls” which both summarization and final generation honor. As is, it does seem to work: model_mode none triggers warnings and then they set dry_run=true which causes generate_from_prompt to just print the prompt.

It might be cleaner if summarize_target also respected dry-run and skipped calling the model (currently if you do `--model-mode none`, it might still run summarize_commit which calls generate_response; though since they set model_mode="none" and pass that in, generate_response would return empty immediately or error).

This flow is a bit convoluted. A refactor could short-circuit summarization when no model is to be used – instead, just concatenate raw commit messages or something.

This ties into perhaps providing a mode where the tool generates a draft prompt for manual use (which it does via `--dry-run` or `--prompt-file` in document). Not a critical bug, but worth reviewing.



## Pending

- CHORE: write doc on using external APIs
- CHORE: Add examples of using giv with various workflows. ie. npm run giv
- ENHANCEMENT: add git config user.name to output
- ENHANCEMENT: add README to summaries/prompt(?)
- ENHANCEMENT: add date token to summary
- FEATURE: ollama, glow, and gh cli included in docker image
- FEATURE: add option to install glow during install
- FEATURE: use glow for output if available
- FEATURE: GIV_USE_GLOW config setting
- FEATURE: .giv folder to hold config and prompts
- FEATURE: init commnand to create folder and basic setup
- FEATURE: enhanced help command
  - milvous cli indexes docs folder, project tree, and usage text
  - allow `giv help "some question here"`
  - use milvious data to provide command suggestions when command fails
- FEATURE: chat with code/history
- FEATURE: improve section updating (ie merge lists, update headers), improve date and header management
- FEATURE: include [SAMPLE] token to provide current or previous section in the prompt
- FEATURE: markdown lint and fixing before output
- FEATURE: option to manually review and update before saving
- FEATURE: option to use LLM to automatically review before final output
  - reviews format and attempts to correct it or sends for a retry
- DOCUMENTATION: Add example of using custom prompt and rules with document subcommand
- DOCUMENTATION: Add example of adding a new document type subcommand
- DOCUMENTATION: Add example of sourcing giv functions in other scripts
- FEATURE: add --no-pager option for when writing to stdout (ie. review or no output-file), default to true for message

- CHORE: Add more "real-world" tests with more detailed output validation
  - long commit histories and summaries
- ENHANCEMENT: allow user to specify (regex?) patterns for matching sections, headers, versions, todos
- ENHANCEMENT: improve prompt with more specific todo rules. ie. BUG->FIXED changes go in ### Fixed sub section
- FEATURE: Add roadmap document type
- FEATURE: chat with TODOs
- FEATURE: Improve rules and examples handling
  - --rules-file
  - --example-file - if "auto" attempt to extract section from output-file
  - 
## Known Issues

- BUG: Announcement needs more project specific context for things like homepage, name, date
- BUG: Changelog including front matter and incorrect header
- BUG: Release notes has incorrect date
- BUG: Docker permissions issues
- BUG: Flatpak does not build
- BUG: Snap does not build
- BUG: RPM, snap, and flatpak are not validated

## In Progress

- TEST: test packages in dist folder in a docker container
  - Add flatpak to docker for building packages
  - Try to fix snap so that it is available in docker to build snap package
- ENHANCEMENT: add project name to summaries(?)
- Publish script that will bump version, build packages, push built packages and create Github release
  - create repos for homebrew and flatpk?
- FEATURE: document command to use prompt file 

## Completed

- ADDED: --summary option to provide summary of changes
- ADDED: --type "annoucement" option to generate a release announcement
- ADDED: --type "commit" option to generate commit message `git commit -m "$(giv -t commit)"
- ADDED: Provide default version file for python and node
- ADDED: Provide a version file arg to override the defaults
- DONE: Refactor code to use functions
- ADDED: Add update function and argument to update script to latest version
- DONE: Add install instructions to README
- ADDED: Switch from --generate to --prompt-only to allow the script to generate the changelog by - default
- DONE: Add "Managed by giv" to change output
- FIXED: Script does not append to end of changelog if no existing sections are found
- ADDED: Add arg to only look at pending changes instead of previous commits
- FIXED: Parsing issue with --to and --from args
- FIXED: install.sh issue with getting latest version
- FIXED: bug with defaulting to --current if no other options are passed
- FIXED: POSIX sh compatibility bug in install.sh
- DONE: move default prompt template into sh file.
- DONE: support remote API for generation
- FIXED: Script should not fail if no todo files are found.
- ADDED: Better support for finding and parsing todo files in sub folders.
- DONE: Added descriptions to help examples
- ADDED: Help now shows the default version files the script will look for.
- ADDED: check to ensure we are in a git repository before running the script.
- ADDED: Better version management for install & update
- ADDED: Improve default prompt text
- ADDED: use temp files for history and prompt. save them based on args
- DONE: replace --prompt-only with --save-prompt
- DONE: Add --save-history to Optionally save history file
- ADDED: add --config-file load .env file to get settings
- ADDED: include a --include-pattern arg to replace the --short-diff arg to allow custom patterns during diff
- ADDED: add an --exclude-pattern arg
- DONE: Cleanup default output file names (ie. prompt.md, history.md)
- FIXED: Always generates changelog, should be able only generate prompts
- ADDED: Add --debug arg to enable debug more
- ADDED: Add --todo-pattern to use in addition to the include/exclude args. The diffs found in this pattern should be used in the todos history section instead of the --include-pattern files
- ADDED: Better git history formatted with more explict version and todo verbiage
- ADDED: If no version changes are found, grep for existing/current verison info in the version file
- DONE: Refactor the handling of --include/exclude so it handles the general diff and not the todos section
- FIXED: Bug with pager displaying on long git diff output
- ADDED: Add --generation-mode with allowed values of "auto", "local", "remote", and "none"
- ADDED: add option to create a prompt template based on the default
- ADDED: Add --update-mode with allowed values of "auto", "prepend", "append", and "update"
- ADDED: Add --section-name to specify which section to when updating the changelog.
  - If not specified it should be generated based on the new or current version information in that priority order. 
  - If not specified and no verison info can be found, then set section name to "Current Changes"
  - If a matching section is found and it contains the current verison and the update-mode is either auto or update, that section should be sent to LLM with instructions to update the section with information about the git history.
  - If matching section is found and the update mode is "prepend" then insert the changelog content before the matching section
  - If no matching section is found and the update mode is "auto" or "prepend" then insert the changelog content after the first # header and before the first ## heading
  - If matching section is found and the update mode is "appened" then insert the changelog content after the matching section and before the next section or at the end of the file.
  - If no matching section is found and the update mode is "append" then insert the changelog content at the end of the file.
- ADDED: use existing section from existing change log in prompt instead of examples items when possible
- FIXED: fix debug flag handling, should default to "" so checks work correctly
- DONE: improve prompt to handle updating existing sections