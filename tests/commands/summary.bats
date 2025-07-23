#!/usr/bin/env bats
# tests/commands/summary.bats

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../helpers/setup.sh'

@test "summary without args fails with usage" {
  run "$GIV_LIB_DIR/commands/summary.sh"
  assert_output --partial "Missing path argument"
}

@test "summary runs against real Git repo" {
  run "$GIV_LIB_DIR/commands/summary.sh" --output="$BATS_TMPDIR/out.txt" "$PROJECT_DIR"
  grep -q "feat: add second line" "$BATS_TMPDIR/out.txt"
}

@test "summary supports custom template" {
  run "$GIV_LIB_DIR/commands/summary.sh" -t simple "$PROJECT_DIR"
  assert_success
  # e.g. template 'simple' might produce a one-line summary
  assert_output --partial "Initial commit; add second line"
}


# Edge case: invalid path
@test "summary with invalid path fails" {
  run "$GIV_LIB_DIR/commands/summary.sh" /nonexistent/path
  assert_failure
  assert_output --partial "No such file or directory"
}

# Edge case: empty repo (no commits)
@test "summary with empty repo returns appropriate message" {
  tmp_empty=$(mktemp -d)
  git -C "$tmp_empty" init >/dev/null 2>&1
  run "$GIV_LIB_DIR/commands/summary.sh" "$tmp_empty"
  assert_failure
  assert_output --partial "No commits found"
  rm -rf "$tmp_empty"
}

# Edge case: non-git directory
@test "summary with non-git directory fails" {
  tmp_dir=$(mktemp -d)
  run "$GIV_LIB_DIR/commands/summary.sh" "$tmp_dir"
  assert_failure
  assert_output --partial "Not a git repository"
  rm -rf "$tmp_dir"
}

# Edge case: corrupted repo
@test "summary with corrupted repo fails gracefully" {
  tmp_corrupt=$(mktemp -d)
  git -C "$tmp_corrupt" init >/dev/null 2>&1
  rm -rf "$tmp_corrupt/.git"
  run "$GIV_LIB_DIR/commands/summary.sh" "$tmp_corrupt"
  assert_failure
  assert_output --partial "Not a git repository"
  rm -rf "$tmp_corrupt"
}

# Edge case: large number of commits
@test "summary handles large commit log" {
  tmp_large=$(mktemp -d)
  git -C "$tmp_large" init >/dev/null 2>&1
  for i in $(seq 1 50); do
    echo "line $i" > "$tmp_large/file.txt"
    git -C "$tmp_large" add file.txt
    git -C "$tmp_large" commit -m "commit $i" >/dev/null 2>&1
  done
  run "$GIV_LIB_DIR/commands/summary.sh" "$tmp_large"
  assert_success
  assert_output --partial "commit 50"
  rm -rf "$tmp_large"
}

# Edge case: special characters in commit messages
@test "summary handles special characters in commit messages" {
  tmp_special=$(mktemp -d)
  git -C "$tmp_special" init >/dev/null 2>&1
  echo "foo" > "$tmp_special/file.txt"
  git -C "$tmp_special" add file.txt
  git -C "$tmp_special" commit -m $'fix: handle emoji 🚀\nnewline\nquote: "test"' >/dev/null 2>&1
  run "$GIV_LIB_DIR/commands/summary.sh" "$tmp_special"
  assert_success
  assert_output --partial "🚀"
  assert_output --partial '"test"'
  rm -rf "$tmp_special"
}
