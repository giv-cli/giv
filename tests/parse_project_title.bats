#!/usr/bin/env bats

load '../src/project.sh'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

export GIV_HOME="$BATS_TEST_DIRNAME/.giv"
export GIV_TMP_DIR="$BATS_TEST_DIRNAME/.giv/.tmp"
setup() {
    TMPDIR_REPO="$(mktemp -d)"
    cd "$TMPDIR_REPO"
}

teardown() {
    cd /
    rm -rf "$TMPDIR_REPO"
}

write_file() {
    filepath="$1"
    shift
    printf "%s\n" "$@" >"$filepath"
}

@test "get_project_title: package.json" {
    write_file package.json \
        '{' \
        '  "name": "my-npm-project",' \
        '  "version": "1.2.3"' \
        '}'
    run get_project_title
    assert_success
    assert_output "my-npm-project"
}

@test "get_project_title: pyproject.toml poetry" {
    write_file pyproject.toml \
        '[tool.poetry]' \
        'name = "my-python-project"' \
        'version = "0.1.0"'
    run get_project_title
    assert_success
    assert_output "my-python-project"
}

@test "get_project_title: pyproject.toml PEP 621" {
    write_file pyproject.toml \
        '[project]' \
        'name = "pep621-project"' \
        'version = "0.2.0"'
    run get_project_title
    assert_success
    # Should still match the first name line
    assert_output "pep621-project"
}

@test "get_project_title: setup.py" {
    write_file setup.py \
        "setup(" \
        "    name='my-setup-project'," \
        "    version='0.2.0'" \
        ")"
    run get_project_title
    assert_success
    assert_output "my-setup-project"
}

@test "get_project_title: Cargo.toml" {
    write_file Cargo.toml \
        '[package]' \
        'name = "my-rust-project"' \
        'version = "0.3.0"'
    run get_project_title
    assert_success
    assert_output "my-rust-project"
}

@test "get_project_title: composer.json" {
    write_file composer.json \
        '{' \
        '  "name": "my-php-project",' \
        '  "version": "1.0.0"' \
        '}'
    run get_project_title
    assert_success
    assert_output "my-php-project"
}

@test "get_project_title: build.gradle" {
    write_file build.gradle \
        "rootProject.name = 'my-gradle-project'"
    run get_project_title
    assert_success
    assert_output "my-gradle-project"
}

@test "get_project_title: pom.xml" {
    write_file pom.xml \
        "<project>" \
        "  <name>my-maven-project</name>" \
        "</project>"
    run get_project_title
    assert_success
    assert_output "my-maven-project"
}

@test "get_project_title: no project files" {
    run get_project_title
    assert_success
    assert_output ""
}

@test "get_project_title: package.json with extra whitespace" {
    write_file package.json \
        '{' \
        '    "name"   :    "whitespace-project"  ,' \
        '    "version": "1.0.0"' \
        '}'
    run get_project_title
    assert_success
    assert_output "whitespace-project"
}

@test "get_project_title: setup.py with double quotes" {
    write_file setup.py \
        'setup(' \
        '    name="double-quoted-project",' \
        '    version="0.2.0"' \
        ')'
    run get_project_title
    assert_success
    assert_output "double-quoted-project"
}

@test "get_project_title: multiple project files, prefers first" {
    write_file package.json \
        '{ "name": "first-project", "version": "1.0.0" }'
    write_file pyproject.toml \
        '[tool.poetry]' \
        'name = "second-project"' \
        'version = "0.2.0"'
    run get_project_title
    assert_success
    assert_output "first-project"
}

@test "get_project_title: build.gradle with double quotes" {
    write_file build.gradle \
        'rootProject.name = "gradle-double-quoted"'
    run get_project_title
    assert_success
    assert_output "gradle-double-quoted"
}

@test "get_project_title: pom.xml with extra tags" {
    write_file pom.xml \
        "<project>" \
        "  <description>desc</description>" \
        "  <name>xml-project</name>" \
        "  <version>1.0.0</version>" \
        "</project>"
    run get_project_title
    assert_success
    assert_output "xml-project"
}