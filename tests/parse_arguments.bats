#!/usr/bin/env bats
load './helpers/setup.sh'
load "${GIV_LIB_DIR}/system.sh"
load "${GIV_LIB_DIR}/argument_parser.sh"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

GIV_SCRIPT="${GIV_SRC_DIR}/giv.sh"
OG_DIR="$(pwd)"
export __VERSION="1.0.0"


setup() {
  # stub out external commands so parse_args doesn't actually exec them
  show_help() { printf 'HELP\n'; }
  show_version() { printf '%s\n' "$__VERSION"; }

  # Mock generate_response function
  generate_response() {
      echo "Mocked response for generate_response"
  }

  # source the script under test
  GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src/lib"
  export GIV_LIB_DIR

  TEST_DIR=$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")
  cd "$TEST_DIR" || exit 1
  # make a dummy config file
  echo "GIV_API_KEY=XYZ" >tmp.cfg
  echo "GIV_API_URL=TEST_URL" >>tmp.cfg
  echo "GIV_API_MODEL=TEST_MODEL" >>tmp.cfg
  echo "GIV_TMPDIR_SAVE=" >>"tmp.cfg"
  chmod +r tmp.cfg
  GIV_TMPDIR_SAVE=

  # Ensure $GIV_HOME/config exists for all tests
  mkdir -p "$GIV_HOME"
  echo "GIV_API_KEY=XYZ" >"$GIV_HOME/config"
  echo "GIV_API_URL=TEST_URL" >>"$GIV_HOME/config"
  echo "GIV_API_MODEL=TEST_MODEL" >>"$GIV_HOME/config"
}

teardown() {
  remove_tmp_dir
  cd "$OG_DIR" || exit 1
  rm -rf "$TEST_DIR"
}

# setup valid git range v1..v2
setup_git_range() {
  rm -rf .git
  git init
  git config user.email "test@example.com"
  git config user.name "Test User"
  echo "a" >a.txt
  git add a.txt
  git commit -m "first"
  git tag v1
  echo "b" >b.txt
  git add b.txt
  git commit -m "second"
  git tag v2
}
# 1. no args → prints "No arguments provided." and exits 0
@test "no arguments prints message and exits zero" {
  run parse_arguments
  echo "$output"
  assert_failure
  assert_output --partial "No arguments provided"
}

# 2. help flags - test disabled for unified parser
@test "help flag triggers help subcommand and exits 0" {
  parse_arguments help
  assert_equal "$GIV_SUBCMD" "help"
}

@test "help via -h triggers help subcommand and exits 0" {
  parse_arguments -h
  assert_equal "$GIV_SUBCMD" "help"
}

# 3. version flags
@test "version flag triggers version subcommand and exits 0" {
  parse_arguments --version  
  assert_equal "$GIV_SUBCMD" "version"
}

@test "version via -v triggers version subcommand and exits 0" {
  parse_arguments -v
  assert_equal "$GIV_SUBCMD" "version"
}

# 4. invalid first argument  
@test "invalid subcommand sets GIV_SUBCMD" {
  parse_arguments foobar
  assert_equal "$GIV_SUBCMD" "foobar"
}

# 5. valid subcommands
@test "subcommand 'message' is accepted" {
  run parse_arguments message --verbose
  assert_success
  [ "$GIV_SUBCMD" = "message" ]
  [ "$GIV_DEBUG" = "true" ]
}

@test "subcommand 'msg' is accepted" {
  run parse_arguments msg --verbose
  assert_success
  [ "$GIV_SUBCMD" = "message" ]
  [ "$GIV_DEBUG" = "true" ]
}

@test "subcommand 'summary' is accepted" {
  parse_arguments summary --verbose
  assert_equal "$GIV_SUBCMD" "summary"
  assert_equal "$GIV_DEBUG" "true"
}

# @test "subcommand 'changelog' is accepted and printed" {
#   skip "Disabled for unified parser" changelog --verbose
#   assert_success
#   assert_output --partial "Subcommand: changelog"
# }

# @test "subcommand 'release-notes' is accepted and printed" {
#   skip "Disabled for unified parser" release-notes --verbose
#   assert_success
#   assert_output --partial "Subcommand: release-notes"
# }

# @test "subcommand 'announcement' is accepted and printed" {
#   skip "Disabled for unified parser" announcement --verbose
#   assert_success
#   assert_output --partial "Subcommand: announcement"
# }

# @test "subcommand 'available-releases' is accepted and printed" {
#   skip "Disabled for unified parser" available-releases --verbose
#   assert_success
#   assert_output --partial "Subcommand: available-releases"
# }

# @test "subcommand 'update' is accepted and printed" {
#   skip "Disabled for unified parser" update --verbose
#   assert_success
#   assert_output --partial "Subcommand: update"
# }

# @test "subcommand 'document' is accepted and printed" {
#   skip "Disabled for unified parser" document --verbose --prompt-file "TEST"
#   assert_success
#   assert_output --partial "Subcommand: document"
# }

# @test "subcommand 'doc' is accepted and printed" {
#   skip "Disabled for unified parser" doc --verbose
#   assert_success
#   assert_output --partial "Subcommand: doc"
# }

# # 6. early --config-file parsing (nonexistent)
# @test "early --config-file=bad prints error but continues" {
#   skip "Disabled for unified parser" message --config-file bad --verbose

#   assert_success
#   assert_output --partial 'WARNING: config file bad not found.'
#   assert_output --partial "Subcommand: message"
# }

# # 7. early --config-file parsing (exists)
# @test "early --config-file tmp.cfg loads and prints it" {
#   skip "Disabled for unified parser" summary --config-file tmp.cfg --verbose
#   assert_success
#   assert_output --partial "Config Loaded: true"
#   assert_output --partial "Config File: tmp.cfg"
#   assert_output --partial "API URL: TEST_URL"
#   assert_output --partial "API Model: TEST_MODEL"
#   assert_output --partial "Subcommand: summary"
# }

# # 8. default TARGET → --current
# @test "no target given defaults to --current" {
#   skip "Disabled for unified parser" summary --verbose
#   assert_success
#   assert_output --partial "Revision: --current"
# }

# # 9. --staged maps to --cached
# @test "--staged becomes --cached internally" {
#   skip "Disabled for unified parser" summary --staged --verbose
#   assert_success
#   assert_output --partial "Revision: --cached"
# }

# # 10. explicit git-range target
# @test "invalid git range as target" {
#   skip "Disabled for unified parser" summary v1..v2 --verbose
#   assert_failure
#   assert_output --partial "ERROR: Invalid commit range: v1..v2"
# }
# # 10. explicit git-range target

# @test "valid git range as target" {
#   setup_git_range
#   skip "Disabled for unified parser" summary v1..v2 --verbose
#   assert_success
#   assert_output --partial "Revision: v1..v2"
# }

# # 11. pattern collection
# @test "positional args after target become pathspec" {
#   setup_git_range
#   skip "Disabled for unified parser" summary v1..v2 "src/**/*.js" --verbose
#   assert_success
#   assert_output --partial "Pathspec: src/**/*.js"
# }

# # 12. global flags: --dry-run
# @test "--dry-run sets dry_run=true" {
#   skip "Disabled for unified parser" summary --dry-run --verbose
#   assert_success
#   assert_output --partial "Pathspec:"
# }

# # 13. unknown option after subcommand
# @test "unknown option errors out" {
#   skip "Disabled for unified parser" summary --no-such-flag
#   [ "$status" -eq 1 ]
#   assert_output --partial "Unknown option or argument: --no-such-flag"
# }

# # 14. --template-dir, --output-file, --todo-pattern etc.
# @test "all known global options parse without error" {
#   skip "Disabled for unified parser" summary \
#     --output-file OUT \
#     --todo-pattern TODO \
#     --prompt-file PROMPT \
#     --model M \
#     --api-model AM \
#     --api-url AU \
#     --output-mode UM \
#     --output-version OV \
#     --version-file VER \
#     --verbose
#   assert_success
#   assert_output --partial "Prompt File: PROMPT"
# }

# # 15. double dash stops option parsing (should error on unknown argument)
# @test "-- stops option parsing (unknown argument after -- triggers error)" {
#   skip "Disabled for unified parser" message -- target-and-pattern --verbose
#   [ "$status" -eq 1 ]
#   assert_output --partial "Unknown option or argument: --"
# }

# @test "no pattern correctly sets target and pattern" {  
#   setup_git_range
#   # echo "GIV_DEBUG=true" >"$GIV_HOME/config"
#   # echo "GIV_MODEL=llama3" >>"$GIV_HOME/config"
#   export GIV_DEBUG="true"
#   skip "Disabled for unified parser" changelog HEAD
#   assert_success
#   echo "Output: $output"
#   assert_output --partial "Subcommand: changelog"
#   assert_output --partial "Revision: HEAD"
#   assert_output --partial "Pathspec: "
# }



# @test "document subcommand without --prompt-file errors out" {
#   skip "Disabled for unified parser" document --verbose
#   [ "$status" -eq 1 ]
#   assert_output --partial "Error: --prompt-file is required for the document subcommand."
# }

# @test "document subcommand with --prompt-file is accepted" {
#   skip "Disabled for unified parser" document --prompt-file PROMPT --verbose
#   assert_success
#   assert_output --partial "Subcommand: document"
#   assert_output --partial "Prompt File: PROMPT"
# }
@test "global parser handles global options" {
    run "${GIV_SCRIPT}" --verbose --dry-run --config-file test-config --help
    assert_success
    assert_output --partial "Usage: giv <subcommand> [revision] [pathspec] [OPTIONS]"
}

@test "document subcommand parser handles arguments correctly" {
    run "${GIV_SCRIPT}" document --prompt-file test-prompt.md --revision HEAD --pathspec src/ --output-file output.md
    assert_success
    assert_output --partial "test-prompt.md"
    assert_output --partial "HEAD"
    assert_output --partial "src/"
    assert_output --partial "output.md"
}

@test "changelog subcommand parser handles arguments correctly" {
    run "${GIV_SCRIPT}" changelog --revision HEAD --pathspec src/ --output-file changelog.md --output-version 1.0.0
    assert_success
    assert_output --partial "HEAD"
    assert_output --partial "src/"
    assert_output --partial "changelog.md"
    assert_output --partial "1.0.0"
}

@test "message subcommand parser handles arguments correctly" {
    run "${GIV_SCRIPT}" message --revision HEAD --pathspec src/ --todo-pattern TODO
    assert_success
    assert_output --partial "HEAD"
    assert_output --partial "src/"
    assert_output --partial "TODO"
}


