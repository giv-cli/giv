#!/bin/sh
# giv-config.sh: Git-style config manager for .giv/config

set -eu

# Ensure GIV_HOME points to the .giv directory
: "${GIV_HOME:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.giv}"
# Ensure GIV_CONFIG_FILE points to the config file within .giv directory  
: "${GIV_CONFIG_FILE:=${GIV_HOME}/config}"



# Configuration management functions
# This file should only be executed by the dispatcher, not sourced by other scripts

# Configuration management functions are defined below
# Execution logic is at the end of the file

# Centralized key normalization
normalize_key() {
    # Takes 'foo.bar' → 'GIV_FOO_BAR', but reject keys with '/'
    case "$1" in
        */*)
            printf ''
            ;;
        *)
            printf 'GIV_%s' "$1" | tr '[:lower:].' '[:upper:]_'
            ;;
    esac
}

# Quote value if it contains spaces, special characters, or is empty
quote_value() {
    case "$1" in
        *[[:space:]]*|*[\"\'\`\$\\]*|'')
            printf '"%s"' "$1"
            ;;
        *)
            printf '%s' "$1"
            ;;
    esac
}

giv_config() {
    cmd="$1"
    case "$cmd" in
        --list|list|show)
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "config file not found" >&2
                return 1
            fi

            if [ ! -s "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "No configuration found." >&2
                return 0
            fi

            # Check for malformed lines
            while IFS= read -r line; do
                case "$line" in
                    '#'*|'') continue ;;  # Skip comments and empty lines
                    *=*) continue ;;      # Valid config line
                    *)
                        printf '%s\n' "Malformed config line: $line" >&2
                        return 1
                        ;;
                esac
            done < "$GIV_CONFIG_FILE"

            # Convert GIV_... keys to user keys for output from config file
            while IFS= read -r line; do
                case "$line" in
                    GIV_*)
                        k=${line#GIV_}
                        k=${k%%=*}
                        key=$(printf '%s' "$k" | tr 'A-Z_' 'a-z.')
                        value="${line#*=}"
                        printf '%s\n' "$key=$value"
                        ;;
                    *=*)
                        printf '%s\n' "$line"
                        ;;
                esac
            done < "$GIV_CONFIG_FILE"
            ;;
        --get|get)
            key="$2"
            # Only support dot-separated keys in the config file
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "config file not found" >&2
                return 1
            fi
            val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
            val=$(printf '%s' "$val" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
            if [ -n "$val" ]; then
                printf '%s\n' "$val"
                return 0
            fi
            # Fallback to GIV_... env var
            env_key="$(normalize_key "$key")"
            env_val="$(printenv "$env_key" 2>/dev/null)"
            if [ -n "$env_val" ]; then
                printf '%s\n' "$env_val"
                return 0
            fi
            # Not found
            return 1
            ;;
        --unset|unset)
            key="$2"
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "config file not found" >&2
                return 1
            fi
            tmpfile=$(mktemp)
            givkey="$(normalize_key "$key")"
            grep -v -E "^($key|$givkey)=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
            mv "$tmpfile" "$GIV_CONFIG_FILE"
            ;;
        --set|set)
            key="$2"
            value="$3"
            mkdir -p "$GIV_HOME"
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                touch "$GIV_CONFIG_FILE"
            fi
            tmpfile=$(mktemp)
            grep -v -E "^$key=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
            printf '%s=%s\n' "$key" "$(quote_value "$value")" >> "$tmpfile"
            mv "$tmpfile" "$GIV_CONFIG_FILE"
            ;;
        -*|help)
            printf '%s\n' "Unknown option: $cmd" >&2
            printf '%s\n' "Usage: giv config [list|get key|set key value|unset key|key [value]]" >&2
            return 1
            ;;
        *)
            key="$1"
            value="${2:-}"
            if [ -z "$value" ]; then
                # ENV override fallback for dot-separated keys
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    printf '%s\n' "config file not found" >&2
                    return 1
                fi
                if [ -s "$GIV_CONFIG_FILE" ]; then
                    if grep -qvE '^(#|[^=]+=.*|[[:space:]]*)$' "$GIV_CONFIG_FILE"; then
                        printf '%s\n' "Malformed config" >&2
                        return 1
                    fi
                fi
                val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                val=$(printf '%s' "$val" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
                if [ -n "$val" ]; then
                    printf '%s\n' "$val"
                    return 0
                fi
                env_key="$(normalize_key "$key")"
                env_val="$(printenv "$env_key" 2>/dev/null)"
                if [ -n "$env_val" ]; then
                    printf '%s\n' "$env_val"
                    return 0
                fi
                return 1
            else
                mkdir -p "$GIV_HOME"
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    touch "$GIV_CONFIG_FILE"
                fi
                tmpfile=$(mktemp)
                grep -v -E "^$key=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
                printf '%s=%s\n' "$key" "$(quote_value "$value")" >> "$tmpfile"
                mv "$tmpfile" "$GIV_CONFIG_FILE"
            fi
            ;;
    esac
}

# Execute the config command when this script is run by the dispatcher
if [ "${1:-}" = "config" ]; then
    shift
fi

# Handle arguments from unified parser
# The unified parser sets GIV_LIST=true when --list flag is used
if [ "${GIV_LIST:-}" = "true" ]; then
    giv_config "--list"
elif [ $# -eq 0 ]; then
    # Default to --list if no arguments  
    giv_config "--list"
else
    giv_config "$@"
fi
