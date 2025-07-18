#!/usr/bin/env bats
set -u
BATS_TEST_START_TIME="$(date +%s)"
mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/error.log"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
SCRIPT="$BATS_TEST_DIRNAME/../src/args.sh"
OG_DIR="$(pwd)"
export GIV_TEMPLATE_DIR="${BATS_TEST_DIRNAME}/../templates"
export __VERSION="1.0.0"
setup() {
  # stub out external commands so parse_args doesn't actually exec them
  show_help() { printf 'HELP\n'; }
  show_version() { printf '%s\n' "$__VERSION"; }
  #is_valid_git_range() { return 0; }

  # stub ollama/command-v checks so we never fall into the remote-mode branches
  command_ollama() { return 0; }
  alias ollama='command_ollama'

  # source the script under test
  source "$SCRIPT"

  TEST_DIR=$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")
  cd "$TEST_DIR" || exit 1
  # make a dummy config file
  echo "GIV_API_KEY=XYZ" >tmp.cfg
  echo "GIV_API_URL=TEST_URL" >>tmp.cfg
  echo "GIV_API_MODEL=TEST_MODEL" >>tmp.cfg
  echo "GIV_TMPDIR_SAVE=" >>"tmp.cfg"
  chmod +r tmp.cfg
  GIV_TMPDIR_SAVE=
}

teardown() {
  remove_tmp_dir
  cd "$OG_DIR" || exit 1
  rm -rf "$TEST_DIR"
}

# setup valid git range v1..v2
setup_git_range() {
  rm -rf .git
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "a" >a.txt
  git add a.txt
  git commit -m "first"
  git tag v1
  echo "b" >b.txt
  git add b.txt
  git commit -m "second"
  git tag v2
}
# 1. no args → prints “No arguments provided.” and exits 0
@test "no arguments prints message and exits zero" {
  run parse_args
  echo "$output"
  assert_failure
  assert_output --partial "No arguments provided"
}

# 2. help flags
@test "help flag triggers show_help and exits 0" {
  run parse_args --help
  assert_success
  assert_output --partial "Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]"
}

@test "help via -h triggers show_help and exits 0" {

  run parse_args -h
  assert_success
  assert_output --partial "Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]"
}

# 3. version flags
@test "version flag triggers show_version and exits 0" {
  run parse_args --version
  assert_success
  assert_output --partial "$__VERSION"
}

@test "version via -v triggers show_version and exits 0" {
  run parse_args -v
  assert_success
  assert_output --partial "$__VERSION"
}

# 4. invalid first argument
@test "invalid subcommand errors out with exit 1" {
  run parse_args foobar
  [ "$status" -eq 1 ]
  assert_output --partial "First argument must be a subcommand"
}

# 5. valid subcommands
@test "subcommand 'message' is accepted and printed" {
  run parse_args message --verbose
  assert_success
  assert_output --partial "Subcommand: message"
}

# 5. valid subcommands
@test "subcommand 'msg' is accepted and printed" {
  run parse_args msg --verbose
  assert_success
  assert_output --partial "Subcommand: msg"
}

@test "subcommand 'summary' is accepted and printed" {
  run parse_args summary --verbose
  assert_success
  assert_output --partial "Subcommand: summary"
}

@test "subcommand 'changelog' is accepted and printed" {
  run parse_args changelog --verbose
  assert_success
  assert_output --partial "Subcommand: changelog"
}

@test "subcommand 'release-notes' is accepted and printed" {
  run parse_args release-notes --verbose
  assert_success
  assert_output --partial "Subcommand: release-notes"
}

@test "subcommand 'announcement' is accepted and printed" {
  run parse_args announcement --verbose
  assert_success
  assert_output --partial "Subcommand: announcement"
}

@test "subcommand 'available-releases' is accepted and printed" {
  run parse_args available-releases --verbose
  assert_success
  assert_output --partial "Subcommand: available-releases"
}

@test "subcommand 'update' is accepted and printed" {
  run parse_args update --verbose
  assert_success
  assert_output --partial "Subcommand: update"
}

@test "subcommand 'document' is accepted and printed" {
  run parse_args document --verbose --prompt-file "TEST"
  assert_success
  assert_output --partial "Subcommand: document"
}

@test "subcommand 'doc' is accepted and printed" {
  run parse_args doc --verbose
  assert_success
  assert_output --partial "Subcommand: doc"
}

# 6. early --config-file parsing (nonexistent)
@test "early --config-file=bad prints error but continues" {
  run parse_args message --config-file bad --verbose

  assert_success
  assert_output --partial 'WARNING: config file bad not found.'
  assert_output --partial "Subcommand: message"
}

# 7. early --config-file parsing (exists)
@test "early --config-file tmp.cfg loads and prints it" {
  run parse_args summary --config-file tmp.cfg --verbose
  assert_success
  assert_output --partial "Config Loaded: true"
  assert_output --partial "Config File: tmp.cfg"
  assert_output --partial "API URL: TEST_URL"
  assert_output --partial "API Model: TEST_MODEL"
  assert_output --partial "Subcommand: summary"
}

# 8. default TARGET → --current
@test "no target given defaults to --current" {
  run parse_args message --verbose
  assert_success
  assert_output --partial "Revision: --current"
}

# 9. --staged maps to --cached
@test "--staged becomes --cached internally" {
  run parse_args message --staged --verbose
  assert_success
  # note: code prints the raw "$1" again, but your logic sets TARGET="--cached"
  assert_output --partial "Revision: --cached"
}

# 10. explicit git-range target
@test "invalid git range as target" {
  run parse_args changelog v1..v2 --verbose
  assert_failure
  # cat $output >> "$ERROR_LOG" # capture output for debugging (uncomment only when debugging)
  assert_output --partial "Error: Invalid commit range: v1..v2"
}
# 10. explicit git-range target

@test "valid git range as target" {
  setup_git_range
  run parse_args changelog v1..v2 --verbose
  assert_success
  # cat $output >> "$ERROR_LOG" # capture output for debugging (uncomment only when debugging)
  assert_output --partial "Revision: v1..v2"
}

# 11. pattern collection
@test "positional args after target become pathspec" {
  setup_git_range
  run parse_args summary v1..v2 "src/**/*.js" --verbose
  assert_success
  assert_output --partial "Pathspec: src/**/*.js"
}

# 12. global flags: --dry-run
@test "--dry-run sets dry_run=true" {
  run parse_args release-notes --dry-run --verbose
  assert_success
  assert_output --partial "Pathspec:"
  # dry_run itself isn’t printed, but no error means flag was accepted
}

# 13. unknown option after subcommand
@test "unknown option errors out" {
  run parse_args message --no-such-flag
  [ "$status" -eq 1 ]
  assert_output --partial "Unknown option or argument: --no-such-flag"
}

# 14. --template-dir, --output-file, --todo-pattern etc.
@test "all known global options parse without error" {
  run parse_args summary \
    --output-file OUT \
    --todo-pattern TODO \
    --prompt-file PROMPT \
    --model M \
    --model-mode P \
    --api-model AM \
    --api-url AU \
    --output-mode UM \
    --output-version OV \
    --version-file VER \
    --verbose
  assert_success
  # spot-check a couple
  assert_output --partial "Prompt File: PROMPT"
  assert_output --partial "Config File:"
  assert_output --partial "Output Version: OV"
}

# 15. double dash stops option parsing (should error on unknown argument)
@test "-- stops option parsing (unknown argument after -- triggers error)" {
  run parse_args message -- target-and-pattern --verbose
  [ "$status" -eq 1 ]
  assert_output --partial "Unknown option or argument: --"
}

@test "no pattern correctly sets target and pattern" {  
  setup_git_range
  ollama() { echo "ollama called"; }
  export GIV_DEBUG="true"
  run parse_args changelog HEAD
  echo "$output"
  assert_success
  assert_output --partial "Subcommand: changelog"
  assert_output --partial "Revision: HEAD"
  assert_output --partial "Pathspec: "
}



@test "document subcommand without --prompt-file errors out" {
  run parse_args document --verbose
  [ "$status" -eq 1 ]
  assert_output --partial "Error: --prompt-file is required for the document subcommand."
}

@test "document subcommand with --prompt-file is accepted" {
  run parse_args document --prompt-file PROMPT --verbose
  assert_success
  assert_output --partial "Subcommand: document"
  assert_output --partial "Prompt File: PROMPT"
}


