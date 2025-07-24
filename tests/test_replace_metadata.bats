# #!/usr/bin/env bats

# load 'test_helper/bats-support/load'
# load 'test_helper/bats-assert/load'
# load "$BATS_TEST_DIRNAME/../src/system.sh"
# load "$BATS_TEST_DIRNAME/../src/llm.sh"
# export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"

# setup() {
#   export GIV_METADATA_TITLE="Test Title"
#   export GIV_METADATA_DESCRIPTION="Test Description"
#   export GIV_METADATA_VERSION="1.0.0"
#   export GIV_DEBUG="true"
#   export -p GIV_METADATA_TITLE
#   export -p GIV_METADATA_DESCRIPTION
#   export -p GIV_METADATA_VERSION
#   cd "$GIV_TMP_DIR"
# }

# teardown() {
#   unset GIV_METADATA_TITLE
#   unset GIV_METADATA_DESCRIPTION
#   unset GIV_METADATA_VERSION
# }

# @test "replace_metadata replaces placeholders with GIV_METADATA_ variables" {
#   echo "[TITLE] - [DESCRIPTION] - [VERSION]" > input.txt
#   run env GIV_METADATA_TITLE="Test Title" GIV_METADATA_DESCRIPTION="Test Description" GIV_METADATA_VERSION="1.0.0" bash -c "cat input.txt | source $BATS_TEST_DIRNAME/../src/llm.sh; replace_metadata"
#   assert_success
#   assert_output "Test Title - Test Description - 1.0.0"
# }

# @test "replace_metadata handles missing variables gracefully" {
#   echo "[TITLE] - [MISSING] - [VERSION]" > input.txt
#   run env GIV_METADATA_TITLE="Test Title" GIV_METADATA_DESCRIPTION="Test Description" GIV_METADATA_VERSION="1.0.0" bash -c "cat input.txt | source $BATS_TEST_DIRNAME/../src/llm.sh; replace_metadata"
#   assert_success
#   assert_output "Test Title - [MISSING] - 1.0.0"
# }

