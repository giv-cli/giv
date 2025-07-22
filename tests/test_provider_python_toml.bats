#!/usr/bin/env bats

# Load helper functions
load "test_helper/bats-support/load"
load "test_helper/bats-assert/load"

setup() {
  # Create a temporary directory for the test
  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR" || return

  # Create a sample pyproject.toml file
  cat <<EOF > pyproject.toml
name = "example-project"
version = "1.2.3"
EOF

  # Source the provider script to make its functions available
  . "${BATS_TEST_DIRNAME}/../src/project/providers/provider_python_toml.sh"
}

teardown() {
  # Clean up the temporary directory
  rm -rf "$TMP_DIR"
}

@test "provider_python_toml_detect detects pyproject.toml" {
  run provider_python_toml_detect
  assert_success
}

@test "provider_python_toml_collect extracts metadata" {
  run provider_python_toml_collect
  assert_success
  assert_output --partial "title=\"example-project\""
  assert_output --partial "version=\"1.2.3\""
  assert_output --partial "language=\"python\""
}

@test "provider_python_toml_get_version extracts version" {
  run provider_python_toml_get_version
  assert_success
  assert_output "1.2.3"
}

@test "provider_python_toml_get_version_at_commit extracts version from a commit" {
  # Initialize a git repository and commit the pyproject.toml file
  git init
  git add pyproject.toml
  git commit -m "Add pyproject.toml"

  # Modify the version and commit again
  echo "version = \"2.0.0\"" > pyproject.toml
  git add pyproject.toml
  git commit -m "Update version to 2.0.0"

  # Test the version at the first commit
  first_commit=$(git rev-list --max-parents=0 HEAD)
  run provider_python_toml_get_version_at_commit "$first_commit"
  assert_success
  assert_output "1.2.3"
}
