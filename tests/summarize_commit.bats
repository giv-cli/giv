#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project.sh"
load "$BATS_TEST_DIRNAME/../src/llm.sh"

    export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"
    export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
setup() {

    export GIV_DEBUG="true"
    TMP_REPO="$BATS_TEST_DIRNAME/.tmp/tmp_repo"
    rm -rf "$TMP_REPO"
    mkdir -p "$TMP_REPO"
    cd "$TMP_REPO" || exit 1
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"

    echo "first" >a.txt
    git add a.txt
    git commit -q -m "first"
    FIRST_SHA=$(git rev-parse HEAD)

    echo "second" >b.txt
    git add b.txt
    git commit -q -m "second"

    # Mock generate_response function
    generate_response() {
        echo "Mocked response for generate_response"
    }

    . "$BATS_TEST_DIRNAME/../src/history.sh"
}

teardown() {
    rm -rf "$TMP_REPO"
}

@test "summarize_commit caches and returns summary" {
    summary_cache="$GIV_HOME/cache/${FIRST_SHA}-summary.md"
    rm -f "$summary_cache"

    run summarize_commit "$FIRST_SHA"
    assert_success

    [ -f "$summary_cache" ]
    run cat "$summary_cache"
    assert_success
}

@test "summarize_commit handles missing templates" {
    export GIV_TEMPLATE_DIR="/nonexistent"
    export GIV_DEBUG="true"
    rm -rf "$GIV_HOME/cache/"  # clean up any old cache
    mkdir -p "$GIV_HOME/cache"
    run summarize_commit "$FIRST_SHA"
    assert_failure
    assert_output --partial "ERROR: Template file not found: /nonexistent/summary_prompt.md"
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
  rm -rf "$GIV_HOME/cache/*.*"  # clean up any old cache
  GIV_DEBUG="true"
  result=$(summarize_commit HEAD "" "remote" >out.txt)
  assert_success
  printf "Output: %s\n" "$result"

  # should have mocked response in out.txt
  run cat out.txt
  assert_output --partial "Mocked response for generate_response"
}