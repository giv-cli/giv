# #!/usr/bin/env bats

# load 'test_helper/bats-support/load'
# load 'test_helper/bats-assert/load'

# load "$BATS_TEST_DIRNAME/../src/config.sh"
# . "$BATS_TEST_DIRNAME/../src/system.sh"

# export ERROR_LOG="$BATS_TEST_DIRNAME/.logs/main.error.log"
# export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
# export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
# setup_file() {
#   : >"$ERROR_LOG"
# }

# setup() {
#   export GIV_TEMPLATE_DIR="$BATS_TEST_DIRNAME/../templates"
#   mkdir -p "$GIV_TEMPLATE_DIR"

#   ORIG_DIR="$PWD"
#   mkdir -p "$BATS_TEST_DIRNAME/.tmp"
#   BATS_TMP_DIR="$(mktemp -d -p "$BATS_TEST_DIRNAME/.tmp")"

#   mkdir -p "$BATS_TMP_DIR"
#   mkdir -p "$BATS_TEST_DIRNAME/.logs"
#   cd "$BATS_TMP_DIR"
#   git init -q
#   git config user.name "Test"
#   git config user.email "test@example.com"
#   GIV_SCRIPT="$BATS_TEST_DIRNAME/../src/giv.sh"


#   set_config
#   cp -f "$GIV_HOME/config" ".env"
#   mock_generate_remote "dummy" "Hello from remote!"
#   mock_curl "dummy" "Hello from remote!"

#   GIV_TMPDIR_SAVE="false"


# }

# teardown() {
#   remove_tmp_dir
#   rm -rf "${BATS_TMP_DIR}"
#   cd "${ORIG_DIR:-$PWD}" 2>/dev/null || true
#   rm -f "$GIV_HOME/config" || true
# }

# # ---- Helpers ----
# set_config() {
#     # Set required environment variables
#   printf 'GIV_API_KEY="test-api-key"\n' > "$GIV_HOME/config"
#   printf 'GIV_MODEL="devstral"\n' >> "$GIV_HOME/config"
#   printf 'GIV_API_URL="https://api.example.com"\n' >> "$GIV_HOME/config"
# }
# mock_ollama() {
#   arg1="${1:-dummy}"
#   arg2="${2:-Ollama message}"
#   mkdir -p bin
#   cat >bin/ollama <<EOF
# #!/bin/bash
# echo "Ollama command: \$1"
# echo "Using model: \$2"
# echo "Ollama arg1: $arg1"
# echo "Ollama arg2: $arg2"
# echo "Ollama run complete"
# if [ "\$3" ]; then
#   echo "\$3"
# fi
# EOF
#   chmod +x bin/ollama
#   export PATH="$PWD/bin:$PATH"
# }

# mock_generate_remote() {
#   endpoint="${1:-dummy}"
#   message="${2:-Hello from curl!}"
#   mkdir -p bin
#   cat >bin/generate_remote <<EOF
# #!/bin/bash
# echo "$message"
# EOF
#   chmod +x bin/generate_remote
#   export PATH="$PWD/bin:$PATH"
# }

# mock_curl() {
#   endpoint="${1:-dummy}"
#   message="${2:-Hello from curl!}"

#   case "$endpoint" in
#     "dummy")
#       printf '%s\n%s\n' "$endpoint" "$message"
#       ;;
#     "generate_response")
#       printf '{"response": "%s"}\n' "$message"
#       ;;
#     "error_case")
#       printf '{"error": "Simulated error"}\n' >&2
#       return 1
#       ;;
#     *)
#       printf '{"error": "Unknown endpoint: %s"}\n' "$endpoint" >&2
#       return 1
#       ;;
#   esac
# }

# gen_commits() {
#   for f in a b c; do
#     echo "$f" >"$f.txt" && git add "$f.txt" && git commit -m "add $f.txt"
#   done
# }

# # ---- Global Options & Help ----

# @test "Prints version" {
#   run "$GIV_SCRIPT" --version
#   assert_success
#   echo "$output" | grep -E "[0-9]+\.[0-9]+\.[0-9]+"
# }

# @test "Prints help with subcommands" {
#   run "$GIV_SCRIPT" --help
#   assert_success
#   echo "$output" | grep -q "Usage: giv"
#   echo "$output" | grep -q "message"
#   echo "$output" | grep -q "changelog"
#   echo "$output" | grep -q "release-notes"
#   echo "$output" | grep -q "available-releases"
# }

# @test "Unknown flag errors" {
#   run "$GIV_SCRIPT" --nope
#   assert_failure
#   assert_output --partial "First argument must be a subcommand or -h/--help/-v/--version"
# }

# # ---- MESSAGE SUBCOMMAND ----
# @test "Generate message for HEAD (default)" {
#   echo "msg" >m.txt && git add m.txt && git commit -m "commit for message"
#   run "$GIV_SCRIPT" message HEAD
#   assert_success
#   echo "$output" | grep -iq "commit"
# }

# @test "Generate message for working tree --current" {
#   mock_generate_remote "dummy" "Working Tree changes\updated wt.txt\nbar in wt2.txt"

#   echo "foo" >"wt.txt"
#   git add .
#   git commit -m "wt commit"
#   echo "updated" >"wt.txt"
#   echo "bar" >"wt2.txt"

#   run "$GIV_SCRIPT" message --current --verbose
#   assert_success
#   assert_output --partial "Working Tree changes"
#   assert_output --partial "wt.txt"
#   assert_output --partial "wt2.txt"
# }

# @test "Message: for commit range" {
#   gen_commits
#   mock_generate_remote "dummy" "Commit range message"
#   run "$GIV_SCRIPT" message HEAD~2..HEAD --verbose
#   assert_success
#   assert_output --partial "add b.txt"
# }

# @test "Message: with file pattern" {
#   mock_generate_remote "dummy" "Patterned message for bar.py"
#   echo "bar" >bar.py && git add bar.py && git commit -m "python file"
#   run "$GIV_SCRIPT" message HEAD "*.py" --verbose
#   assert_success
#   assert_output --partial "python file"
# }

# # ---- SUMMARY SUBCOMMAND ----

# @test "Generate summary for HEAD" {

#   echo "summary" >s.txt && git add s.txt && git commit -m "sum"
#   run "$GIV_SCRIPT" summary HEAD --verbose
#   assert_success
#   assert_output --partial "sum"
# }

# @test "Summary for commit range with pattern" {
#   gen_commits
#   mock_generate_remote "dummy" "Summary for a.txt and b.txt"
#   run "$GIV_SCRIPT" summary HEAD~2..HEAD "*.txt"
#   assert_success
#   assert_output --partial "a.txt"
# }

# # ---- CHANGELOG SUBCOMMAND ----

# @test "Changelog for last commit (HEAD)" {
#   echo "clog" >c.txt && git add c.txt && git commit -m "clogmsg"
#   mock_generate_remote "dummy" "- feat: clog"

#   run "$GIV_SCRIPT" changelog HEAD
#   assert_success
#   echo "$output"
#   cat CHANGELOG.md
#   grep -q "clog" CHANGELOG.md
# }

# @test "Changelog for commit range" {
#   gen_commits
#   mock_generate_remote "dummy" "- update a b c"
#   run "$GIV_SCRIPT" changelog HEAD~2..HEAD
#   cat CHANGELOG.md
#   assert_success
#   grep -q "update a b c" CHANGELOG.md
# }

# @test "Changelog for staged (--cached)" {
#   echo "stage" >stage.txt && git add stage.txt
#   mock_generate_remote "dummy" "- staged"
#   run "$GIV_SCRIPT" changelog --cached
#   assert_success
#   grep -q "staged" CHANGELOG.md
# }

# @test "Changelog with file pattern" {
#   echo "bar" >bar.md && git add bar.md && git commit -m "docs"
#   mock_generate_remote "dummy" "- bar.md"
#   run "$GIV_SCRIPT" changelog HEAD "*.md"
#   assert_success
#   grep -q "bar.md" CHANGELOG.md
# }

# @test "Changelog for working tree (--current)" {
#   echo "z" >z.md
#   mock_generate_remote "dummy" "- z.md"
#   run "$GIV_SCRIPT" changelog --current
#   assert_success
#   grep -q "z.md" CHANGELOG.md
# }

# @test "Changelog with output mode prepend and version" {
#   echo "# Changelog" >CHANGELOG.md
#   echo "## v1.0.0" >>CHANGELOG.md
#   echo "- old" >>CHANGELOG.md
#   echo "new" >n.txt && git add n.txt && git commit -m "new commit"
#   mock_generate_remote "dummy" "- new change"
#   run "$GIV_SCRIPT" changelog HEAD --output-mode prepend --output-version "v1.0.0"
#   assert_success
#   cat CHANGELOG.md
#   grep -q "new change" CHANGELOG.md
#   grep -q "v1.0.0" CHANGELOG.md
# }

# # ---- RELEASE-NOTES SUBCOMMAND ----

# @test "Release notes for range" {
#   gen_commits
#   mock_generate_remote "dummy" "- relnote"
#   run "$GIV_SCRIPT" release-notes HEAD~2..HEAD
#   assert_success
#   grep -q "relnote" RELEASE_NOTES.md
# }

# @test "Release notes for range dry-run" {
#   gen_commits
#   mock_generate_remote "dummy" "relnote"
#   echo "" >".env"
#   run "$GIV_SCRIPT" release-notes HEAD~2..HEAD --dry-run #--verbose
#   assert_success
#   assert_output --partial "relnote"
# }
# # ---- ANNOUNCEMENT SUBCOMMAND ----

# @test "Announcement for HEAD" {
#   echo "announce" >an.txt && git add an.txt && git commit -m "an"
#   mock_generate_remote "dummy" "- announce"
#   run "$GIV_SCRIPT" announcement HEAD
#   assert_success
#   [ -f "ANNOUNCEMENT.md" ]
#   grep -q "announce" ANNOUNCEMENT.md
# }

# # ---- AVAILABLE-RELEASES & UPDATE ----

# @test "Available releases outputs tags" {
#   mkdir -p stubs
#   cat >stubs/curl <<EOF
# #!/bin/bash
# echo '[
#   {
#     "url": "https://api.github.com/repos/giv-cli/giv/releases/228995989",
#     "assets_url": "https://api.github.com/repos/giv-cli/giv/releases/228995989/assets",
#     "upload_url": "https://uploads.github.com/repos/giv-cli/giv/releases/228995989/assets{?name,label}",
#     "html_url": "https://github.com/giv-cli/giv/releases/tag/0.2.0",
#     "id": 228995989,
#     "author": {
#       "login": "giv-cli",
#       "id": 6414031,
#       "node_id": "MDQ6VXNlcjY0MTQwMzE=",
#       "avatar_url": "https://avatars.githubusercontent.com/u/6414031?v=4",
#       "gravatar_id": "",
#       "url": "https://api.github.com/users/giv-cli",
#       "html_url": "https://github.com/giv-cli",
#       "followers_url": "https://api.github.com/users/giv-cli/followers",
#       "following_url": "https://api.github.com/users/giv-cli/following{/other_user}",
#       "gists_url": "https://api.github.com/users/giv-cli/gists{/gist_id}",
#       "starred_url": "https://api.github.com/users/giv-cli/starred{/owner}{/repo}",
#       "subscriptions_url": "https://api.github.com/users/giv-cli/subscriptions",
#       "organizations_url": "https://api.github.com/users/giv-cli/orgs",
#       "repos_url": "https://api.github.com/users/giv-cli/repos",
#       "events_url": "https://api.github.com/users/giv-cli/events{/privacy}",
#       "received_events_url": "https://api.github.com/users/giv-cli/received_events",
#       "type": "User",
#       "user_view_type": "public",
#       "site_admin": false
#     },
#     "node_id": "RE_kwDOO8Gcbs4NpjOV",
#     "tag_name": "0.2.0",
#     "target_commitish": "main",
#     "name": "0.2.0",
#     "draft": false,
#     "prerelease": false,
#     "created_at": "2025-07-01T02:39:16Z",
#     "published_at": "2025-07-01T05:59:26Z",
#     "assets": [],
#     "tarball_url": "https://api.github.com/repos/giv-cli/giv/tarball/0.2.0",
#     "zipball_url": "https://api.github.com/repos/giv-cli/giv/zipball/0.2.0",
#     "body": "## What'\''s New in v0.2.0"
#   },
#   {
#     "url": "https://api.github.com/repos/giv-cli/giv/releases/226567952",
#     "assets_url": "https://api.github.com/repos/giv-cli/giv/releases/226567952/assets",
#     "upload_url": "https://uploads.github.com/repos/giv-cli/giv/releases/226567952/assets{?name,label}",
#     "html_url": "https://github.com/giv-cli/giv/releases/tag/v0.1.10",
#     "id": 226567952,
#     "author": {
#       "login": "giv-cli",
#       "id": 6414031,
#       "node_id": "MDQ6VXNlcjY0MTQwMzE=",
#       "avatar_url": "https://avatars.githubusercontent.com/u/6414031?v=4",
#       "gravatar_id": "",
#       "url": "https://api.github.com/users/giv-cli",
#       "html_url": "https://github.com/giv-cli",
#       "followers_url": "https://api.github.com/users/giv-cli/followers",
#       "following_url": "https://api.github.com/users/giv-cli/following{/other_user}",
#       "gists_url": "https://api.github.com/users/giv-cli/gists{/gist_id}",
#       "starred_url": "https://api.github.com/users/giv-cli/starred{/owner}{/repo}",
#       "subscriptions_url": "https://api.github.com/users/giv-cli/subscriptions",
#       "organizations_url": "https://api.github.com/users/giv-cli/orgs",
#       "repos_url": "https://api.github.com/users/giv-cli/repos",
#       "events_url": "https://api.github.com/users/giv-cli/events{/privacy}",
#       "received_events_url": "https://api.github.com/users/giv-cli/received_events",
#       "type": "User",
#       "user_view_type": "public",
#       "site_admin": false
#     },
#     "node_id": "RE_kwDOO8Gcbs4NgScQ",
#     "tag_name": "v0.1.10",
#     "target_commitish": "main",
#     "name": "v0.1.10",
#     "draft": false,
#     "prerelease": false,
#     "created_at": "2025-06-20T03:05:11Z",
#     "published_at": "2025-06-20T03:07:47Z",
#     "assets": [],
#     "tarball_url": "https://api.github.com/repos/giv-cli/giv/tarball/v0.1.10",
#     "zipball_url": "https://api.github.com/repos/giv-cli/giv/zipball/v0.1.10",
#     "body": "## What'\''s Changed"
#   }
# ]'
# EOF
#   chmod +x stubs/curl
#   export PATH="$PWD/stubs:$PATH"
#   run "$GIV_SCRIPT" available-releases
#   assert_success
#   assert_output --partial "0.2.0"
#   assert_output --partial "v0.1.10"
# }

# @test "Update subcommand calls installer" {
#   mkdir -p stubs
#   cat >stubs/sh <<EOF
# #!/bin/bash
# echo "installer called: \$@"
# EOF
#   chmod +x stubs/sh
#   export PATH="$PWD/stubs:$PATH"
#   run "$GIV_SCRIPT" update
#   assert_success
#   assert_output --partial "installer called"
# }

# # ---- MODEL/CONFIG/ENV OVERRIDES ----

# @test "Model options override config/env for message" {
#   export GIV_MODEL=llama2
#   gen_commits
#   mock_generate_remote "dummy" "- mocked"
#   echo "GIV_MODEL=llama2" >.env
#   run "$GIV_SCRIPT" message HEAD --model phi --verbose
#   assert_success
#   assert_output --partial "phi"
# }
# @test "Config defaults to GIV_HOME/config" {
#   echo "GIV_MODEL=llama3" >"$GIV_HOME/config"

#   mock_generate_remote "dummy" "- llama3"

#   gen_commits
#   run "$GIV_SCRIPT" summary HEAD
#   assert_success
#   assert_output --partial "Using model: llama3"
#   rm -f "$GIV_HOME/config"  # Clean up after test
# }
# @test "Config file overrides .env" {

#   echo "GIV_MODEL=llama3" >"$GIV_HOME/config"
#   tmpfile=$(mktemp)
#   echo "GIV_MODEL=phi3" >"$tmpfile"
#   gen_commits
#   run "$GIV_SCRIPT" summary HEAD --config-file "$tmpfile" --verbose
#   assert_success
#   assert_output --partial "phi3"
#   rm -f "$GIV_HOME/config"  # Clean up after test
# }

# @test "Env API key required for remote" {
#   unset GIV_API_KEY
#   gen_commits
#   GIV_DEBUG="true"
#   run "$GIV_SCRIPT" changelog HEAD --api-url http://fake --api-model dummy
#   assert_output --partial "GIV_API_KEY"
# }

# # ---- ERROR CASES ----

# @test "Fails gracefully outside git repo" {

#   run "$GIV_SCRIPT" changelog HEAD
#   assert_failure
#   assert_output --partial "ERROR: Invalid target: HEAD"
# }

# @test "Fails on unknown subcommand" {
#   run "$GIV_SCRIPT" doesnotexist
#   assert_failure
#   assert_output --partial "First argument must be a subcommand or -h/--help/-v/--version"
# }

# @test "Fails for bad config file path" {
#   run "$GIV_SCRIPT" message HEAD --config-file doesnotexist.env
#   assert_output --partial "WARNING: config file doesnotexist.env not found."
# }

# ## TODO: Fix this test
# # @test "Fails for bad version file path" {
# #   run "$GIV_SCRIPT" changelog HEAD --version-file doesnotexist.ver
# #   assert_output --partial "version file"
# # }

# @test "Fails for repo with no commits" {
#   rm -rf .git
#   git init -q
#   run "$GIV_SCRIPT" changelog HEAD --verbose
#   assert_failure
#   assert_output --partial "ERROR: Invalid target: HEAD"
# }

# # ---- OUTPUT FILES ----

# @test "Changelog outputs CHANGELOG.md" {
#   echo "foo" >foo.txt && git add foo.txt && git commit -m "cl"
#   mock_generate_remote "dummy" "- changelog"
#   run "$GIV_SCRIPT" changelog HEAD --verbose
#   assert_success
#   echo "$output"
#   [ -f CHANGELOG.md ]
#   cat CHANGELOG.md >&2
#   grep -q "Changelog" CHANGELOG.md
# }

# @test "Release notes outputs RELEASE_NOTES.md" {
#   echo "rel" >rel.txt && git add rel.txt && git commit -m "rel"
#   mock_generate_remote "dummy" "- relnote"
#   run "$GIV_SCRIPT" release-notes HEAD
#   assert_success
#   [ -f RELEASE_NOTES.md ]
#   assert_output --partial "Response written to RELEASE_NOTES.md"
# }

# @test "Announce outputs ANNOUNCEMENT.md" {
#   gen_commits
#   echo "ann" >ann.txt && git add ann.txt && git commit -m "ann"
#   mock_generate_remote "dummy" "- announce"
#   run "$GIV_SCRIPT" announcement HEAD~3..HEAD

#   # printf 'Output: %s\n' "$output"
#   # printf '\n----\n'
#   assert_success
#   [ -f ANNOUNCEMENT.md ]
#   grep -q "announce" ANNOUNCEMENT.md
# }
