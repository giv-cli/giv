#!/usr/bin/env bats
export TMPDIR="/tmp"
export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/llm.sh"
load "$BATS_TEST_DIRNAME/../src/history.sh"

setup() {

    export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
    export GIV_DEBUG="true"
    TMP_REPO="$BATS_TEST_DIRNAME/.tmp/tmp_repo"
    rm -rf "$TMP_REPO"
    mkdir -p "$TMP_REPO"
    mkdir -p "$TMP_REPO/.giv/.tmp"
    mkdir -p "$TMP_REPO/.giv/cache"
    mkdir -p "$TMP_REPO/.giv/templates"
    cd "$TMP_REPO" || exit 1
    git init
    git config user.name "Test"
    git config user.email "test@example.com"
    echo ".giv/" > .gitignore
    git add .gitignore
    git commit -q -m "add .gitignore"
    export GIV_HOME="$TMP_REPO/.giv"
    export GIV_TMP_DIR="$TMP_REPO/.giv/.tmp"
    export TMPDIR="$GIV_TMP_DIR"
    mkdir -p "$GIV_TMP_DIR"
    echo "api.key=XYZ
api.url=TEST_URL
api.model=TEST_MODEL" > "$GIV_HOME/config"
    git init -q
    git config user.name "Test"
    git config user.email "test@example.com"

    # Create minimal package.json for version extraction before any commit
    echo '{"version": "0.0.0"}' > package.json
    git add package.json

    echo "first" >a.txt
    git add a.txt
    git commit -q -m "first"
    FIRST_SHA=$(git rev-parse HEAD)

    echo "second" >b.txt
    git add b.txt
    git commit -q -m "second"

    # Create minimal package.json for version extraction
    echo '{"version": "1.2.3"}' > package.json
    git add package.json
    git commit -q -m "add package.json"

    # Mock generate_response function
    generate_response() {
        echo "Mocked response for generate_response"
    }

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
  run summarize_commit HEAD "" "remote"
  assert_success
  printf "Output: %s\n" "$output"

  assert_output --partial "Mocked response for generate_response"
}