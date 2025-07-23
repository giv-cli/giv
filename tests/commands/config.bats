#!/usr/bin/env bats
# tests/commands/config.bats

load '../test_helper/bats-support/load'
load '../test_helper/bats-assert/load'
load '../helpers/setup.sh'

setup(){
    reset_config    
}

@test "config command list" {
 echo "DEBUG: GIV_CONFIG_FILE=$GIV_CONFIG_FILE"
  cat "$GIV_CONFIG_FILE"
  run "$GIV_LIB_DIR/commands/config.sh" list
  assert_success
  assert_output --partial "api.url="
}

# Edge case: missing config file
@test "config command with missing config file fails gracefully" {
  mv "$GIV_HOME/.giv/config" "$GIV_HOME/.giv/config.bak"
  run "$GIV_LIB_DIR/commands/config.sh" list
  assert_failure
  assert_output --partial "config file not found"
  mv "$GIV_HOME/.giv/config.bak" "$GIV_HOME/.giv/config"
}

# Edge case: malformed config file
@test "config command with malformed config file" {
  echo "not_a_key_value" > "$GIV_HOME/.giv/config"
  run "$GIV_LIB_DIR/commands/config.sh" list
  assert_failure
  assert_output --partial "Malformed config"
  echo "api_url=https://api.example.test" > "$GIV_HOME/.giv/config"
}

# Print specific config key
@test "config command prints specific key" {
  run "$GIV_LIB_DIR/commands/config.sh" get api.url
  assert_success
  assert_output --partial "https://api.example.test"
}

# Set and print config value
@test "config command sets and prints value" {
  run "$GIV_LIB_DIR/commands/config.sh" set token test-token
  assert_success
  run "$GIV_LIB_DIR/commands/config.sh" get token
  assert_output --partial "test-token"
}

# Environment variable override
@test "config command respects environment variable override" {
 export GIV_API_URL="override-url"
  run env GIV_API_URL="override-url" "$GIV_LIB_DIR/commands/config.sh" api.url
  assert_output "override-url"
}
