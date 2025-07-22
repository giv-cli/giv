#!/usr/bin/env bats
export TMPDIR="/tmp"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/providers/provider_node_pkg.sh"

setup() {
  touch package.json
}

teardown() {
  rm -f package.json
}

@test "provider_node_pkg_detect returns success if package.json exists" {
  run provider_node_pkg_detect
  assert_success
}

@test "provider_node_pkg_detect returns failure if package.json does not exist" {
  rm -f package.json
  run provider_node_pkg_detect
  assert_failure
}

@test "provider_node_pkg_collect outputs metadata correctly" {
  echo '{"name": "Test Project", "description": "A test project", "version": "1.0.0", "repository": {"url": "https://github.com/test/repo"}, "author": "Test Author"}' > package.json
  run provider_node_pkg_collect
  assert_success
  assert_line "title=\"Test Project\""
  assert_line "description=\"A test project\""
  assert_line "latest_version=\"1.0.0\""
  assert_line "repository_url=\"https://github.com/test/repo\""
  assert_line "author=\"Test Author\""
}

@test "provider_node_pkg_collect handles missing fields gracefully" {
  echo '{"name": "Test Project"}' > package.json
  run provider_node_pkg_collect
  assert_success
  assert_output --partial "title=\"Test Project\""
  assert_line "title=\"Test Project\""
  refute_line "description"
  refute_line "latest_version"
  refute_line "repository_url"
  refute_line "author"
}
