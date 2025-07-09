#!/usr/bin/env bats

load '../src/helpers.sh'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

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

@test "parse_project_title: package.json" {
    write_file package.json \
        '{' \
        '  "name": "my-npm-project",' \
        '  "version": "1.2.3"' \
        '}'
    run parse_project_title
    assert_success
    assert_output "my-npm-project"
}

@test "parse_project_title: pyproject.toml poetry" {
    write_file pyproject.toml \
        '[tool.poetry]' \
        'name = "my-python-project"' \
        'version = "0.1.0"'
    run parse_project_title
    assert_success
    assert_output "my-python-project"
}

@test "parse_project_title: pyproject.toml PEP 621" {
    write_file pyproject.toml \
        '[project]' \
        'name = "pep621-project"' \
        'version = "0.2.0"'
    run parse_project_title
    assert_success
    # Should still match the first name line
    assert_output "pep621-project"
}

@test "parse_project_title: setup.py" {
    write_file setup.py \
        "setup(" \
        "    name='my-setup-project'," \
        "    version='0.2.0'" \
        ")"
    run parse_project_title
    assert_success
    assert_output "my-setup-project"
}

@test "parse_project_title: Cargo.toml" {
    write_file Cargo.toml \
        '[package]' \
        'name = "my-rust-project"' \
        'version = "0.3.0"'
    run parse_project_title
    assert_success
    assert_output "my-rust-project"
}

@test "parse_project_title: composer.json" {
    write_file composer.json \
        '{' \
        '  "name": "my-php-project",' \
        '  "version": "1.0.0"' \
        '}'
    run parse_project_title
    assert_success
    assert_output "my-php-project"
}

@test "parse_project_title: build.gradle" {
    write_file build.gradle \
        "rootProject.name = 'my-gradle-project'"
    run parse_project_title
    assert_success
    assert_output "my-gradle-project"
}

@test "parse_project_title: pom.xml" {
    write_file pom.xml \
        "<project>" \
        "  <name>my-maven-project</name>" \
        "</project>"
    run parse_project_title
    assert_success
    assert_output "my-maven-project"
}

@test "parse_project_title: no project files" {
    run parse_project_title
    assert_success
    assert_output ""
}

@test "parse_project_title: package.json with extra whitespace" {
    write_file package.json \
        '{' \
        '    "name"   :    "whitespace-project"  ,' \
        '    "version": "1.0.0"' \
        '}'
    run parse_project_title
    assert_success
    assert_output "whitespace-project"
}

@test "parse_project_title: setup.py with double quotes" {
    write_file setup.py \
        'setup(' \
        '    name="double-quoted-project",' \
        '    version="0.2.0"' \
        ')'
    run parse_project_title
    assert_success
    assert_output "double-quoted-project"
}

@test "parse_project_title: multiple project files, prefers first" {
    write_file package.json \
        '{ "name": "first-project", "version": "1.0.0" }'
    write_file pyproject.toml \
        '[tool.poetry]' \
        'name = "second-project"' \
        'version = "0.2.0"'
    run parse_project_title
    assert_success
    assert_output "first-project"
}

@test "parse_project_title: build.gradle with double quotes" {
    write_file build.gradle \
        'rootProject.name = "gradle-double-quoted"'
    run parse_project_title
    assert_success
    assert_output "gradle-double-quoted"
}

@test "parse_project_title: pom.xml with extra tags" {
    write_file pom.xml \
        "<project>" \
        "  <description>desc</description>" \
        "  <name>xml-project</name>" \
        "  <version>1.0.0</version>" \
        "</project>"
    run parse_project_title
    assert_success
    assert_output "xml-project"
}