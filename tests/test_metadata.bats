#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/metadata.sh"

# Set up environment variables
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_CACHE_DIR="$GIV_HOME/cache"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src/project"

setup() {
  mkdir -p "$GIV_CACHE_DIR"
  export ENV_FILE="$GIV_HOME/env_file" # Initialize ENV_FILE with a valid path
  touch "$ENV_FILE" # Ensure the file exists
}

teardown() {
  rm -rf "$GIV_HOME"
}

@test "metadata_init creates cache directory and .env file" {
  export GIV_DEBUG="true"
  run metadata_init
  assert_success
  [ -d "$GIV_CACHE_DIR" ]
  [ -f "$GIV_CACHE_DIR/project_metadata.env" ]
}

@test "metadata_init writes metadata with GIV_METADATA_ prefix" {
  export GIV_PROJECT_TYPE="custom"
  echo "title=Test Project" > "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
  grep -q "GIV_METADATA_TITLE=Test Project" "$GIV_CACHE_DIR/project_metadata.env"
}

@test "metadata_init handles missing project_metadata.env gracefully" {
  export GIV_PROJECT_TYPE="custom"
  rm -f "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
}

@test "metadata_init applies overrides correctly" {
  export GIV_PROJECT_TYPE="custom"
  echo "title=Original Title" > "$GIV_HOME/project_metadata.env"
  echo "title=Overridden Title" >> "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
  grep -q "GIV_METADATA_TITLE=Overridden Title" "$GIV_CACHE_DIR/project_metadata.env"
}

@test "metadata_init removes duplicate variables before adding new lines" {
  export GIV_PROJECT_TYPE="custom"
  echo "GIV_METADATA_TITLE=Old Title" > "$GIV_CACHE_DIR/project_metadata.env"
  echo "title=New Title" > "$GIV_HOME/project_metadata.env"
  run metadata_init
  assert_success
  grep -q "GIV_METADATA_TITLE=New Title" "$GIV_CACHE_DIR/project_metadata.env"
  ! grep -q "GIV_METADATA_TITLE=Old Title" "$GIV_CACHE_DIR/project_metadata.env"
}

@test "metadata_init fails if GIV_CACHE_DIR is not set" {
  unset GIV_CACHE_DIR
  run  metadata_init
  assert_failure
}

@test "metadata_init handles invalid provider scripts gracefully" {
  export GIV_PROJECT_TYPE="invalid"
  run  metadata_init
  assert_failure
}
