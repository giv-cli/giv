#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"

@test "ensure_giv_dir creates .giv directory and files" {
    
   {
    cd "$BATS_TEST_DIRNAME/.tmp"
    rm -rf "$(pwd)/.giv"  # Clean up any existing .giv directory
    run ensure_giv_dir_init
    assert_success
    
    [ -d "$(pwd)/.giv" ]
    [ -f "$(pwd)/.giv/config" ]
    [ -d "$(pwd)/.giv/cache" ]
    [ -d "$(pwd)/.giv/.tmp" ]
    [ -d "$(pwd)/.giv/templates" ]
   }

}

