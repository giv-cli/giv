#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

@test "ensure_giv_dir creates .giv directory and files" {
    export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
    export GIV_DOCS_DIR="$BATS_TEST_DIRNAME/../docs"
    export GIV_DEBUG="true"
   {
    rm -rf "$GIV_HOME"  # Clean up any existing .giv directory
    run ensure_giv_dir_init
    assert_success
    
    [ -d "$GIV_HOME" ]
    [ -f "$GIV_HOME/config" ]
    [ -d "$GIV_HOME/cache" ]
    [ -d "$GIV_HOME/.tmp" ]
    [ -d "$GIV_HOME/templates" ]
   }

}

