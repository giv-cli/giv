#!/usr/bin/env bats
load './helpers/setup.sh'
load "${GIV_LIB_DIR}/project_metadata.sh"
load "${GIV_LIB_DIR}/llm.sh"
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    TESTDIR="$(mktemp -d)"
    export TESTDIR

}

teardown() {
    rm -rf "$TESTDIR"
}

@test "build_prompt: basic replacement" {
    template="$TESTDIR/template.md"
    diff="$TESTDIR/diff.txt"
    echo "Summary: [SUMMARY]" > "$template"
    echo "This is a diff" > "$diff"
    run build_prompt --template "$template" --summary "$diff"
    [ "$status" -eq 0 ]
    assert_output --partial "Summary: This is a diff"
    assert_output --partial "Output just the final content—no extra commentary or code fencing. Use only information contained in this prompt and the summaries provided above."
}

@test "build_prompt: all flags replacement" {
    template="$TESTDIR/template.md"
    diff="$TESTDIR/diff.txt"
    cat > "$template" <<EOF
Project: [PROJECT_TITLE]
Version: [VERSION]
Example: [EXAMPLE]
Rules: [RULES]
Summary: [SUMMARY]
EOF
    echo "DIFF_CONTENT" > "$diff"
    run build_prompt --project-title "MyProj" --version "1.2.3" \
        --example "eg" --rules "rulez" \
        --template "$template" --summary "$diff"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Project: MyProj"* ]]
    [[ "$output" == *"Version: 1.2.3"* ]]
    [[ "$output" == *"Example: eg"* ]]
    [[ "$output" == *"Rules: rulez"* ]]
    [[ "$output" == *"Summary: DIFF_CONTENT"* ]]
}

@test "build_prompt: missing template file fails" {
    diff="$TESTDIR/diff.txt"
    touch "$diff"
    run build_prompt --template "no_such_template.md" --summary "$diff"
    [ "$status" -ne 0 ]
    [[ "$output" == *"template file not found"* ]]
}

@test "build_prompt: missing diff file fails" {
    template="$TESTDIR/template.md"
    touch "$template"
    run build_prompt --template "$template" --summary "no_such_diff.txt"
    [ "$status" -ne 0 ]
    [[ "$output" == *"diff file not found"* ]]
}

@test "build_prompt: environment fallback for version" {
    template="$TESTDIR/template.md"
    diff="$TESTDIR/diff.txt"
    echo "Version: [VERSION]" > "$template"
    echo "irrelevant" > "$diff"
    export GIV_TOKEN_VERSION="9.9.9"
    run build_prompt --template "$template" --summary "$diff"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Version: 9.9.9"* ]]
}

# @test "get_project_title: package.json" {
#     cd "$TESTDIR"
#     echo '{ "name": "my-npm-project" }' > package.json
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-npm-project" ]
# }

# @test "get_project_title: pyproject.toml" {
#     cd "$TESTDIR"
#     echo 'name = "my-python-project"' > pyproject.toml
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-python-project" ]
# }

# @test "get_project_title: setup.py (double quotes)" {
#     cd "$TESTDIR"
#     echo 'name = "my-setup-project"' > setup.py
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-setup-project" ]
# }

# @test "get_project_title: setup.py (single quotes)" {
#     cd "$TESTDIR"
#     echo "name = 'my-setup-single'" > setup.py
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-setup-single" ]
# }

# @test "get_project_title: Cargo.toml" {
#     cd "$TESTDIR"
#     echo 'name = "my-cargo-project"' > Cargo.toml
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-cargo-project" ]
# }

# @test "get_project_title: composer.json" {
#     cd "$TESTDIR"
#     echo '{ "name": "my-composer-project" }' > composer.json
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-composer-project" ]
# }

# @test "get_project_title: build.gradle (double quotes)" {
#     cd "$TESTDIR"
#     echo 'rootProject.name = "my-gradle-project"' > build.gradle
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-gradle-project" ]
# }

# @test "get_project_title: build.gradle (single quotes)" {
#     cd "$TESTDIR"
#     echo "rootProject.name = 'my-gradle-single'" > build.gradle
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-gradle-single" ]
# }

# @test "get_project_title: pom.xml" {
#     cd "$TESTDIR"
#     cat > pom.xml <<EOF
# <project>
#   <name>my-maven-project</name>
# </project>
# EOF
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ "$output" = "my-maven-project" ]
# }

# @test "get_project_title: no project file returns empty" {
#     cd "$TESTDIR"
#     rm -f package.json pyproject.toml setup.py Cargo.toml composer.json build.gradle pom.xml
#     run get_project_title
#     [ "$status" -eq 0 ]
#     [ -z "$output" ]
# }

# @test "parse_version: v-prefixed version" {
#     run parse_version "release v1.2.3"
#     [ "$status" -eq 0 ]
#     [ "$output" = "v1.2.3" ]
# }

# @test "parse_version: plain version" {
#     run parse_version "version 2.3.4"
#     [ "$status" -eq 0 ]
#     [ "$output" = "2.3.4" ]
# }

# @test "parse_version: no version returns empty" {
#     run parse_version "no version here"
#     [ "$status" -eq 0 ]
#     [ -z "$output" ]
# }