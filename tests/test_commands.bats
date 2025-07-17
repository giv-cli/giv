#!/usr/bin/env bats

mkdir -p "$BATS_TEST_DIRNAME/.logs"
export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/commands.log"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

BATS_TEST_START_TIME="$(date +%s)"

# shellcheck source=../src/giv.sh
SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"
# shellcheck source=../src/commands.sh
HELPERS="$BATS_TEST_DIRNAME/../src/commands.sh"
# shellcheck source=../src/giv.sh
TEMPLATES_DIR="$BATS_TEST_DIRNAME/../templates"

setup() {
  # create a temp git repo
  REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
  GIV_TMPDIR_SAVE=
  cd "$REPO"
  git init -q
  git config user.name "Test"
  git config user.email "test@example.com"
  # make two commits
  echo "one" >file.txt
  git add file.txt
  git commit -q -m "first commit"
  echo "two" >>file.txt
  git commit -q -am "second commit"

  # make helper stubs
  build_history() { printf "HIST:%s\n" "$2" >"$1"; }
  generate_response() { echo "RESP"; }
  portable_mktemp() { mktemp; }
  get_current_version() { echo "1.2.3"; }
  mock_ollama "dummy" "Ollama message"

  # prompts and file globals
  default_summary_prompt="DEF_SUM"
  commit_message_prompt="DEF_MSG"
  # release_file="release.out"
  # announce_file="announce.out"
  # changelog_file="changelog.out"

  # no dry_run by default
  unset dry_run
  export debug="1"

  # load the script under test
  # shellcheck source=../src/giv.sh
  source "$SCRIPT"

  load "$HELPERS"
}

teardown() {
  remove_tmp_dir
  rm -rf "$REPO"
  rm -f *.out

}

mock_ollama() {
  arg1="${1:-dummy}"
  arg2="${2:-Ollama message}"
  mkdir -p bin
  cat >bin/ollama <<EOF
#!/bin/bash
echo "Ollama command: \$1"
echo "Using model: \$2"
echo "Ollama arg1: $arg1"
echo "Ollama arg2: $arg2"
echo "Ollama run complete"
if [ "\$3" ]; then
  echo "Ollama in verbose mode \$3"
fi
EOF
  chmod +x bin/ollama
  export PATH="$PWD/bin:$PATH"
}
#----------------------------------------
# summarize_commit
#----------------------------------------
@test "summarize_commit writes RESP to out_file" {
  # force portable_mktemp to yield deterministic files
  COUNT=0
  portable_mktemp() {
    if [ "$COUNT" -eq 0 ]; then
      COUNT=1
      echo hist.tmp
    else
      echo pr.tmp
    fi
  }

  rm -f hist.tmp pr.tmp out.txt

  mock_ollama "dummy" "RESP"
  summarize_commit HEAD PROMPT >out.txt

  # should have RESP in out.txt
  run cat out.txt
  assert_output --partial "RESP"
}

#----------------------------------------
# summarize_target
#----------------------------------------
@test "summarize_target on single-commit range" {
  tmp="$(mktemp)"

  generate_response() { echo "RESP"; }
  export debug="true"
  # call inside the real repo
  summarize_target HEAD~1..HEAD $tmp ""
  run cat "$tmp"
  cat "$tmp"
  # expect two commits, each followed by two blank lines
  expected="RESP"
  assert_output --partial "$expected"

  rm -f "$tmp"
}

@test "summarize_target on --current" {
  tmp="$(mktemp)"
  mock_ollama "dummy" "CUR"
  summarize_target --current "$tmp" ""
  run cat "$tmp"
  # one invocation + two newlines
  assert_output --partial 'CUR'
  rm -f "$tmp"
}

#----------------------------------------
# cmd_message
#----------------------------------------
@test "cmd_message with no id errors" {
  echo "some working changes" >"$REPO/file.txt"
  mock_ollama "dummy" "some working changes"
  debug=
  run cmd_message ""
  assert_success
  assert_output --partial "some working changes"
}
@test "cmd_message --current prints message" {
  echo "change" >"$REPO/file.txt"
  mock_ollama "dummy" "change"
  run cmd_message "--current"
  assert_success
  echo "$output"
  assert_output --partial "change"
}
@test "cmd_message single-commit prints message" {
  run git -C "$REPO" rev-parse HEAD~1 # ensure HEAD~1 exists
  debug=
  run cmd_message HEAD~1
  [ "$status" -eq 0 ]
  assert_output "first commit"
}

@test "cmd_message invalid commit errors" {
  run cmd_message deadbeef
  [ "$status" -eq 1 ]
  assert_output --partial "Error: Invalid commit ID"
}

@test "cmd_message range prints both messages" {
  # ensure HEAD~2 exists
  run git -C "$REPO" rev-parse HEAD~2
  echo "first commit" >"$REPO/file.txt"
  git add file.txt
  git commit -m "first commit"
  echo "second commit" >>"$REPO/file.txt"
  git commit -am "second commit"
  debug=
  run cmd_message HEAD~2..HEAD
  assert_success
  assert_output $'first commit\n\nsecond commit'
}

@test "cmd_message HEAD prints commit message" {
  # ensure TODO_PATTERN matches something
  echo "TODO: something" >>"$REPO/file.txt"
  git add file.txt
  git commit -m "add TODO"
  export GIV_DEBUG="true"
  run cmd_message "HEAD" "" "TODO" "auto"
  assert_success
  assert_output --partial "add TODO"
}

#----------------------------------------
# cmd_summary
#----------------------------------------
@test "cmd_summary prints to stdout" {
  summarize_target() { echo "SUM"; }

  run cmd_document "$TEMPLATES_DIR/final_summary_prompt.md" "--current" "" "auto" "0.7" ""
  assert_success
  assert_output --partial "SUM"
}

@test "cmd_summary HEAD~1 prints to stdout" {
  ollama() {
    echo "SUM"
  }
  run cmd_document "$TEMPLATES_DIR/final_summary_prompt.md" HEAD~1 "" "" "auto" "0.7"
  assert_success
  assert_output --partial "SUM"
}

@test "cmd_summary writes to file when output_file set" {
  output_file="out.sum"
  summarize_target() { echo "SUM"; }
  run cmd_document "$TEMPLATES_DIR/final_summary_prompt.md" "--current" "" "${output_file}" "auto"
  assert_success
  [ -f out.sum ]
  assert_output --partial "Response written to out.sum"
  rm -f out.sum
}

@test "cmd_release_notes writes to its default file" {
  run cmd_document "$TEMPLATES_DIR/release_notes_prompt.md" "" "" "RELEASE_NOTES.md"
  assert_success
  assert_output --partial "Response written to RELEASE_NOTES.md"
}

@test "cmd_announcement writes to its default file" {
  run cmd_document "$TEMPLATES_DIR/announcement_prompt.md" "" "" "ANNOUNCEMENT.md"
  assert_success
  assert_output --partial "Response written to ANNOUNCEMENT.md"
}

@test "cmd_changelog writes to its default file" {
  export GIV_DEBUG="true"
  export GIV_OUTPUT_VERSION=""
  export GIV_OUTPUT_MODE="auto"
  run cmd_changelog "HEAD" ""
  assert_success
  assert_output --partial "Changelog written to CHANGELOG.md"
}
