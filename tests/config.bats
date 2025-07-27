#!/usr/bin/env bats
# tests/commands/config.bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load 'helpers/setup.sh'

setup(){
    reset_config    
}

@test "config command list" {
 echo "DEBUG: GIV_CONFIG_FILE=$GIV_CONFIG_FILE"
  cat "$GIV_CONFIG_FILE"
  run "$GIV_SRC_DIR/commands/config.sh" list
  assert_success
  assert_output --partial "api.url="
}

# Edge case: missing config file
@test "config command with missing config file fails gracefully" {
  mv "$GIV_HOME/config" "$GIV_HOME/config.bak"
  run "$GIV_SRC_DIR/commands/config.sh" list
  assert_failure
  assert_output --partial "config file not found"
  mv "$GIV_HOME/config.bak" "$GIV_HOME/config"
}

# Edge case: malformed config file
@test "config command with malformed config file" {
  echo "not_a_key_value" > "$GIV_HOME/config"
  run "$GIV_SRC_DIR/commands/config.sh" list
  assert_failure
  assert_output --partial "Malformed config"
  echo "api.url=https://api.example.test" > "$GIV_HOME/config"
}

# Set and print config value
@test "config command sets and prints value" {
  run "$GIV_SRC_DIR/commands/config.sh" set token test-token
  assert_success
  echo "DEBUG: config file after set:" >&2
  cat "$GIV_HOME/config" >&2
  run "$GIV_SRC_DIR/commands/config.sh" get token
  assert_output --partial "test-token"
}

# Print specific config key
@test "config command prints specific key" {
  echo "api.url=https://api.example.test" > "$GIV_HOME/config"
  echo "DEBUG: config file before get:" >&2
  cat "$GIV_HOME/config" >&2
  run "$GIV_SRC_DIR/commands/config.sh" get api.url
  assert_success
  assert_output --partial "https://api.example.test"
}

# Environment variable override
@test "config command respects environment variable override" {
 export GIV_API_URL="override-url"
  run env GIV_API_URL="override-url" "$GIV_SRC_DIR/commands/config.sh" api.url
  assert_output "override-url"
}
