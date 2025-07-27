#!/usr/bin/env bats
load './helpers/setup.sh'
load "${GIV_LIB_DIR}/system.sh"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "ensure_giv_dir creates .giv directory and files" {
  

   {
    rm -rf "$GIV_HOME"  # Clean up any existing .giv directory
    run ensure_giv_dir_init
    assert_success
    
    [ -d "$GIV_HOME" ]
    [ -f "$GIV_HOME/config" ]
    [ -d "$GIV_HOME/cache" ]
    [ -d "$GIV_HOME/.tmp" ]
    [ -d "$GIV_HOME/templates" ]

    rm -f "$GIV_HOME/config"  # Clean up after test
   }

}

