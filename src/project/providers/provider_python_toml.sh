#!/bin/sh
# provider_python_toml.sh - Python project provider using pyproject.toml

provider_python_toml_detect() {
    [ -f pyproject.toml ]
}

provider_python_toml_collect() {
    # Extract metadata from pyproject.toml
    title=$(awk -F' *= *' '/^name *=/ { gsub(/"/, "", $2); print $2; exit }' pyproject.toml)
    version=$(awk -F' *= *' '/^version *=/ { gsub(/"/, "", $2); print $2; exit }' pyproject.toml)
    echo "title	$title"
    echo "version	$version"
    echo "language	python"
}

provider_python_toml_get_version() {
    awk -F' *= *' '/^version *=/ { gsub(/"/, "", $2); print $2; exit }' pyproject.toml
}

provider_python_toml_get_version_at_commit() {
    commit="$1"
    file_content=$(git show "$commit:pyproject.toml") || return 1
    printf '%s\n' "$file_content" | awk -F' *= *' '/^version *=/ { gsub(/"/, "", $2); print $2; exit }'
}
