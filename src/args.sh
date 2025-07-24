#!/bin/sh
# args_simple.sh: Help functionality only (argument parsing now handled by unified parser)

show_help() {
    cat <<EOF
Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]

Argument        Meaning
--------------- ------------------------------------------------------------------------------
revision        Any Git revision or revision-range (HEAD, v1.2.3, abc123, HEAD~2..HEAD, origin/main...HEAD, --cached, --current)
pathspec        Standard Git pathspec to narrow scope—supports magic prefixes, negation (! or :(exclude)), and case-insensitive :(icase)

Option Groups

General
  -h, --help            Show this help and exit
  -v, --version         Show giv version
  --verbose             Enable debug/trace output
  --dry-run             Preview only; don't write any files
  --config-file PATH    Shell config file to source before running

Revision & Path Selection (what to read)
  (positional) revision   Git revision or range
  (positional) pathspec   Git pathspec filter

Diff & Content Filters (what to keep)
  --todo-files PATHSPEC   Pathspec for files to scan for TODOs
  --todo-pattern REGEX    Regex to match TODO lines
  --version-file PATHSPEC Pathspec of file(s) to inspect for version bumps
  --version-pattern REGEX Custom regex to identify version strings

AI / Model (how to think)
  --model MODEL          Specify the local or remote model name
  --api-model MODEL      Remote model name
  --api-url URL          Remote API endpoint URL
  --api-key KEY          API key for remote mode

Output Behavior (where to write)
  --output-mode MODE     auto, prepend, append, update, none
  --output-version NAME  Override section header/tag name
  --output-file PATH     Destination file (defaults per subcommand)
  --prompt-file PATH     Markdown prompt template to use (required for 'document')

Maintenance Subcommands
  available-releases     List available script versions
  update                 Self-update giv to latest or specified version

Subcommands
  message                Draft an AI commit message (default)
  summary                Human-readable summary of changes
  changelog              Create or update CHANGELOG.md
  release-notes          Generate release notes for a tagged release
  announcement           Create a marketing-style announcement
  document               Generate custom content using your own prompt template
  init                   Initialize or update giv configuration
  config                 Initialize or update giv configuration values
  available-releases     List script versions
  update                 Self-update giv

Examples:
  giv message HEAD~3..HEAD src/
  giv summary --output-file SUMMARY.md
  giv changelog v1.0.0..HEAD --todo-files '*.js' --todo-pattern 'TODO:'
  giv release-notes v1.2.0..HEAD --api-model gpt-4o --api-url https://api.example.com
  giv announcement --output-file ANNOUNCE.md
  giv document --prompt-file templates/my_custom_prompt.md --output-file REPORT.md HEAD
EOF
    printf '\nFor more information, see the documentation at %s\n' "${DOCS_DIR:-<no docs dir>}"
}