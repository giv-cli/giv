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
        --list|list)
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "config file not found" >&2
                return 1
            fi
            # Check for malformed lines
            if [ -s "$GIV_CONFIG_FILE" ]; then
                # Updated malformed config check to ignore empty lines and lines with only whitespace
                # Simple validation: check for lines that don't contain = and aren't comments or empty
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
            fi
            # Convert GIV_... keys to user keys for output from config file
            if [ -s "$GIV_CONFIG_FILE" ]; then
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
                        *)
                        ;;
                    esac
                done < "$GIV_CONFIG_FILE"
            fi
            
            # Also show environment variables with GIV_ prefix that may have been loaded from --config-file
            for var in $(env | grep '^GIV_'); do
                case "$var" in
                    GIV_*)
                        k=${var#GIV_}
                        k=${k%%=*}
                        key=$(printf '%s' "$k" | tr 'A-Z_' 'a-z.')
                        value="${var#*=}"
                        # Only show if not already shown from config file
                        if [ -z "$(grep "^GIV_$k=" "$GIV_CONFIG_FILE" 2>/dev/null)" ]; then
                            printf '%s\n' "$key=$value"
                        fi
                        ;;
                esac
            done
            ;;
        --get|get)
            key="$2"
            # Validate key format
            env_key="$(normalize_key "$key")"
            if [ -z "$env_key" ]; then
                printf '%s\n' "Invalid key format: $key" >&2
                return 1
            fi
            # ENV override
            if [ -n "$env_key" ]; then
                eval "env_val=\"\${$env_key-}\""
                if [ -n "$env_val" ]; then
                    printf '%s\n' "$env_val"
                    return 0
                fi
            fi
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                printf '%s\n' "config file not found" >&2
                return 1
            fi

            # Try user key first, then GIV_ key
            val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
            if [ -z "$val" ]; then
                givkey="$(normalize_key "$key")"
                val=$(grep -E "^$givkey=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
            fi
            # Remove surrounding quotes if present (both single and double)
            val=$(printf '%s' "$val" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
            printf '%s\n' "$val"
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
            givkey="$(normalize_key "$key")"
            grep -v -E "^($key|$givkey)=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
            # Always write in GIV_... format
            writekey="$(normalize_key "$key")"
            printf '%s=%s\n' "$writekey" "$(quote_value "$value")" >> "$tmpfile"
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
            # Validate key format
            env_key="$(normalize_key "$key")"
            if [ -z "$env_key" ]; then
                printf '%s\n' "Invalid key format: $key" >&2
                return 1
            fi
            if [ -z "$value" ]; then
                # ENV override
                if [ -n "$env_key" ]; then
                    eval "env_val=\"\${$env_key-}\""
                    if [ -n "$env_val" ]; then
                        printf '%s\n' "$env_val"
                        return 0
                    fi
                fi
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    printf '%s\n' "config file not found" >&2
                    return 1
                fi
                if [ -s "$GIV_CONFIG_FILE" ]; then
                    # Updated malformed config check to ignore empty lines and lines with only whitespace
                    if grep -qvE '^(#|[^=]+=.*|[[:space:]]*)$' "$GIV_CONFIG_FILE"; then
                        printf '%s\n' "Malformed config" >&2
                        return 1
                    fi
                fi
                val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                if [ -z "$val" ]; then
                    givkey="$(normalize_key "$key")"
                    val=$(grep -E "^$givkey=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                fi
                # Remove surrounding quotes if present (both single and double)
                val=$(printf '%s' "$val" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/")
                printf '%s\n' "$val"
            else
                mkdir -p "$GIV_HOME"
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    touch "$GIV_CONFIG_FILE"
                fi
                tmpfile=$(mktemp)
                givkey="$(normalize_key "$key")"
                grep -v -E "^($key|$givkey)=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
                # Always write in GIV_... format
                writekey="$(normalize_key "$key")"
                printf '%s=%s\n' "$writekey" "$(quote_value "$value")" >> "$tmpfile"
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
