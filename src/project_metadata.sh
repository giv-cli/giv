#!/bin/sh
# metadata_extract.sh - Project metadata extractor for use by other scripts
# Usage: metadata_get_value <key> <commit_id>
# Requires: GIV_PROJECT_TYPE to be set to 'node' or 'python'

# Read file content from working directory or Git history
metadata_get_file_content() {
  file_path="$1"
  commit="$2"

  if [ "$commit" = "HEAD" ] || [ "$commit" = "--current" ] || [ -z "$commit" ]; then
    cat "$file_path" 2>/dev/null || return 1
  elif [ "$commit" = "--cached" ]; then
    git show ":$file_path" 2>/dev/null || return 1
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
      match($0, k "[[:space:]]*=[[:space:]]*\"([^\"]+)\"", arr)
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

  # Always detect project type if set to auto
  project_type="${GIV_PROJECT_TYPE:-auto}"
  if [ "$project_type" = "auto" ]; then
    project_type=$(detect_project_type)
  fi

  case "$project_type" in
    node)
      file="package.json"
      if ! content=$(metadata_get_file_content "$file" "$commit"); then
        return 1
      fi
      if command -v jq >/dev/null 2>&1; then
        value=$(printf '%s' "$content" | jq -r ".${key}")
        [ "$value" = "null" ] && value=""
      else
        value=$(printf '%s' "$content" | awk -v k="$key" '
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
        ')
      fi
      ;;
    python)
      file="pyproject.toml"
      if ! content=$(metadata_get_file_content "$file" "$commit"); then
        return 1
      fi
      if [ "$key" = "version" ]; then
        value=$(printf '%s' "$content" | awk '/^\[project\]/{flag=1;next}/^\[/{flag=0}flag' | grep -m1 -E '^version[[:space:]]*=' | sed -r 's/^version[[:space:]]*=[[:space:]]*"(.*)".*/\1/')
      else
        value=$(printf '%s' "$content" | awk -v k="$key" '
          section=""
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
        ')
      fi
      ;;
    custom)
      file="${GIV_PROJECT_VERSION_FILE:-version.txt}"
      if ! content=$(metadata_get_file_content "$file" "$commit"); then
        return 1
      fi
      value=$(printf '%s' "$content" | awk -v k="$key" '
      BEGIN { IGNORECASE = 1 }
      $0 ~ k {
        gsub(/^[[:space:]]*/, "", $0)  # Remove leading whitespace
        if ($0 ~ k "[[:space:]]*=") {
          # Extract value after =, removing quotes and whitespace
          split($0, parts, "=")
          if (length(parts) >= 2) {
            val = parts[2]
            gsub(/^[[:space:]]*/, "", val)  # Remove leading whitespace  
            gsub(/[[:space:]]*$/, "", val)  # Remove trailing whitespace
            gsub(/^["'"'"']/, "", val)      # Remove leading quote
            gsub(/["'"'"']$/, "", val)      # Remove trailing quote
            print val
            exit
          }
        }
      }
      ')
      ;;
    *)
      value=""
      ;;
  esac

  if [ -n "$value" ]; then
    echo "$value"
  fi
}
