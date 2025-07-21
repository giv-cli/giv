#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'
load "$BATS_TEST_DIRNAME/../src/config.sh"
load "$BATS_TEST_DIRNAME/../src/system.sh"
load "$BATS_TEST_DIRNAME/../src/project/metadata.sh"
load "$BATS_TEST_DIRNAME/../src/llm.sh"

export GIV_LIB_DIR="$BATS_TEST_DIRNAME/../src"
setup() {
  export GIV_METADATA_TITLE="Test Title"
  export GIV_METADATA_DESCRIPTION="Test Description"
  export GIV_METADATA_VERSION="1.0.0"
  echo "[TITLE] - [DESCRIPTION] - [VERSION]" > template.txt
  echo "Summary content here." > summary.txt
}

teardown() {
  unset GIV_METADATA_TITLE
  unset GIV_METADATA_DESCRIPTION
  unset GIV_METADATA_VERSION
  rm -f template.txt summary.txt
}

@test "build_prompt calls replace_metadata and replace_tokens" {
  metadata_init
  run build_prompt --template template.txt --summary summary.txt
  assert_success
  assert_output "Test Title - Test Description - 1.0.0\nOutput just the final content—no extra commentary or code fencing. Use only information contained in this prompt and the summaries provided above."
}
