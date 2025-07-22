#!/usr/bin/env bats
export TMPDIR="/tmp"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/metadata.sh"

# Set up environment variables
export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_CACHE_DIR="$GIV_HOME/cache"
export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"

setup() {
  mkdir -p "$GIV_HOME"
   TMPDIR_REPO="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"
    cd "$TMPDIR_REPO" || {
        echo "Failed to change directory to TMPDIR_REPO" >&2
        exit 1
    }
    git init
    git config user.name "Test"
    git config user.email "test@example.com"
    echo "{ \"version\": \"1.0.0\" }" > package.json
    TMPFILE="$(mktemp -p "${TMPDIR_REPO}")"
    export TMPFILE

}

# teardown() {
#   rm -rf "$GIV_HOME"
#   remove_tmp_dir
#   if [ -n "$TMPFILE" ]; then
#       rm -f "$TMPFILE"
#   fi
#   if [ -n "$TMPDIR_REPO" ]; then
#       rm -rf "$TMPDIR_REPO"
#   fi
# }


@test "metadata_init creates cache directory and .env file" {
  export GIV_DEBUG="true"
  export GIV_METADATA_PROJECT_TYPE="custom"
  export GIV_VERSION_FILE="version.txt"
  run metadata_init
  assert_success
  [ -d "$GIV_CACHE_DIR" ]
  [ -f "$GIV_CACHE_DIR/project_metadata.env" ]
}

@test "metadata_init writes metadata with GIV_METADATA_ prefix" {
  export GIV_METADATA_PROJECT_TYPE="custom"
  echo "title=Test Project" > "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_output --partial 'GIV_METADATA_TITLE="Test Project"'
}

@test "metadata_init handles missing project_metadata.env gracefully" {
  export GIV_METADATA_PROJECT_TYPE="custom"
  rm -f "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
}

@test "metadata_init applies overrides correctly" {
  export GIV_METADATA_PROJECT_TYPE="custom"
  echo "title=Original Title" > "$GIV_HOME/project_metadata.env"
  echo "title=Overridden Title" >> "$GIV_HOME/project_metadata.env"
  run  metadata_init
  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_output --partial 'GIV_METADATA_TITLE="Overridden Title"'
}

@test "metadata_init removes duplicate variables before adding new lines" {
  export GIV_METADATA_PROJECT_TYPE="custom"
  mkdir -p "$GIV_CACHE_DIR"
  echo "GIV_METADATA_TITLE=Old Title" > "$GIV_CACHE_DIR/project_metadata.env"
  echo "title=New Title" > "$GIV_HOME/project_metadata.env"
  run metadata_init
  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_output --partial 'GIV_METADATA_TITLE="New Title"'
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  [[ "$output" != *'GIV_METADATA_TITLE="Old Title"'* ]]
}

@test "metadata_init fails if GIV_CACHE_DIR is not set" {
  unset GIV_CACHE_DIR
  run  metadata_init
  assert_failure
}

@test "metadata_init handles invalid provider scripts gracefully" {
  export GIV_METADATA_PROJECT_TYPE="invalid"
  run  metadata_init
  assert_failure
}


# Added tests for metadata cache enhancement and version-file functions.

@test "metadata cache includes project_type" {
  export GIV_METADATA_PROJECT_TYPE="custom"
  export GIV_VERSION_FILE="version.txt"
  echo "version = '1.0.0'" > "$GIV_VERSION_FILE"
  run metadata_init
  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_success
  assert_output --partial "GIV_METADATA_PROJECT_TYPE="
  
}

@test "get_project_version retrieves version" {
  echo "Version: 1.0.0" > file.txt
  export GIV_VERSION_FILE="file.txt"
  export GIV_METADATA_PROJECT_TYPE="custom"
  metadata_init
  run get_project_version --current
  assert_success
  assert_output --partial "1.0.0"
}

@test "get_project_version retrieves historical version" {
  echo "Version: 1.0.0" > file.txt
  git add file.txt
  git commit -m "Add version 1.0.0"
  echo "Version: 2.0.0" > file.txt
  git add file.txt
  git commit -m "Update to version 2.0.0"
  commit_hash=$(git rev-parse HEAD~1)
  export GIV_VERSION_FILE="file.txt"
  export GIV_METADATA_PROJECT_TYPE="custom"
  export GIV_DEBUG="true"
  metadata_init
  
  run get_project_version "$commit_hash"
  assert_success
  assert_output --partial "1.0.0"
}


@test "metadata_init caches all metadata for node_pkg project type" {
  export GIV_METADATA_PROJECT_TYPE="node_pkg"
  export GIV_DEBUG="true"
  echo '{
    "name": "Node Project",
    "description": "A Node.js project",
    "version": "1.2.3",
    "repository": {"url": "https://github.com/node/repo"},
    "author": "Node Author"
  }' > package.json
  rm -f "$GIV_HOME/project_metadata.env"

  metadata_init

  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_output --partial 'GIV_METADATA_TITLE="Node Project"'
  assert_output --partial 'GIV_METADATA_DESCRIPTION="A Node.js project"'
  assert_output --partial 'GIV_METADATA_LATEST_VERSION="1.2.3"'
  assert_output --partial 'GIV_METADATA_REPOSITORY_URL="https://github.com/node/repo"'
  assert_output --partial 'GIV_METADATA_AUTHOR="Node Author"'
}

@test "metadata_init caches all metadata for python_toml project type" {
  export GIV_METADATA_PROJECT_TYPE="python_toml"
  export GIV_DEBUG="true"
  cat <<EOF > pyproject.toml
[tool.poetry]
name = "Python Project"
description = "A Python project"
version = "2.3.4"
[tool.poetry.repository]
url = "https://github.com/python/repo"
[tool.poetry.author]
name = "Python Author"
EOF
  rm -f "$GIV_HOME/project_metadata.env"

  metadata_init

  assert_success
  run cat "$GIV_CACHE_DIR/project_metadata.env"
  assert_output --partial 'GIV_METADATA_TITLE="Python Project"'
  assert_output --partial 'GIV_METADATA_DESCRIPTION="A Python project"'
  assert_output --partial 'GIV_METADATA_VERSION="2.3.4"'
  assert_output --partial 'GIV_METADATA_REPOSITORY="https://github.com/python/repo"'
  assert_output --partial 'GIV_METADATA_AUTHOR="Python Author"'
}


