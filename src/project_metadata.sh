#!/bin/sh
# metadata_extract.sh - Project metadata extractor for use by other scripts
# Usage: metadata_get_value <key> <commit_id>
# Requires: GIV_PROJECT_TYPE to be set to 'node' or 'python'

# Read file content from working directory or Git history
metadata_get_file_content() {
  file_path="$1"
  commit="$2"

  if [ "$commit" = "HEAD" ] || [ -z "$commit" ]; then
    cat "$file_path"
  else
    git show "$commit:$file_path" 2>/dev/null || return 1
  fi
}

# Extract key from package.json (Node)
metadata_parse_node() {
  content="$1"
  key="$2"

  echo "$content" | awk -v k="$key" '
    BEGIN { found=0 }
    $0 ~ "\""k"\"" {
      match($0, "\""k"\"[[:space:]]*:[[:space:]]*\"([^\"]+)\"", arr)
      if (arr[1] != "") {
        print arr[1]
        found=1
        exit
      }
    }
    END { if (!found) exit 1 }
  '
}

# Extract key from pyproject.toml (Python)
metadata_parse_python() {
  content="$1"
  key="$2"
  section=""

  echo "$content" | awk -v k="$key" '
    /^\[project\]/ { section="project"; next }
    /^\[/ { section=""; next }
    section == "project" {
      if ($0 ~ k"[[:space:]]*=") {
        match($0, k"[[:space:]]*=[[:space:]]*\"([^\"]+)\"", arr)
        if (arr[1] != "") {
          print arr[1]
          exit
        }
      }
    }
  '
}

# Added support for 'auto' project type by integrating detect_project_type

detect_project_type() {
    if [ -f "package.json" ]; then
        echo "node"
    elif [ -f "pyproject.toml" ]; then
        echo "python"
    elif [ -f "setup.py" ]; then
        echo "python"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    elif [ -f "composer.json" ]; then
        echo "php"
    elif [ -f "build.gradle" ]; then
        echo "gradle"
    elif [ -f "pom.xml" ]; then
        echo "maven"
    else
        echo "custom"
    fi
}

# Added metadata_parse_custom to handle custom project type
metadata_parse_custom() {
  content="$1"
  key="$2"

  echo "$content" | awk -v k="$key" '
    BEGIN { found=0 }
    $0 ~ k "[[:space:]]*=" {
      match($0, k "[[:space:]]*=[[:space:]]*\"([^"]+)\"", arr)
      if (arr[1] != "") {
        print arr[1]
        found=1
        exit
      }
    }
    END { if (!found) exit 1 }
  '
}

# Updated get_metadata_value to handle invalid commit hashes gracefully
get_metadata_value() {
  key="$1"
  commit="${2:-HEAD}"

  if [ "$GIV_PROJECT_TYPE" = "auto" ]; then
    GIV_PROJECT_TYPE=$(detect_project_type)
  fi

  case "$GIV_PROJECT_TYPE" in
    node)
      file="package.json"
      parser=metadata_parse_node
      ;;
    python)
      file="pyproject.toml"
      parser=metadata_parse_python
      ;;
    custom)
      file="${GIV_PROJECT_VERSION_FILE:-version.txt}"
      parser=metadata_parse_custom
      ;;
    *)
      echo "Unsupported project type: $GIV_PROJECT_TYPE" >&2
      return 1
      ;;
  esac

  if ! content=$(metadata_get_file_content "$file" "$commit"); then
    echo "Error: Could not read $file at commit $commit" >&2
    return 1
  fi

  if ! value="$($parser "$content" "$key")"; then
    echo "Key '$key' not found in $file at commit $commit" >&2
    return 1
  fi

  echo "$value"
}
