#!/bin/sh
# giv-config.sh: Git-style config manager for .giv/config

set -eu

: "${GIV_HOME:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.giv}"
: "${GIV_CONFIG_FILE:=${GIV_HOME}/config}"



# If called as 'giv.sh config ...', shift off the 'config' argument
if [ "${1:-}" = "config" ]; then
    shift
fi

# Default to --list if no arguments
if [ $# -eq 0 ]; then
    set -- --list
fi

# Centralized key normalization
normalize_key() {
    # Takes 'foo.bar' → 'GIV_FOO_BAR', but reject keys with '/'
    case "$1" in
        */*)
            printf ''
            ;;
        *)
            printf '%s' "$1" | tr '[:lower:].' '[:upper:]_'
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
                if grep -qvE '^(#|[^=]+=[^\n]*|[[:space:]]*)$' "$GIV_CONFIG_FILE"; then
                    printf '%s\n' "Malformed config" >&2
                    return 1
                fi
            fi
            # Convert GIV_... keys to user keys for output
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
            ;;
        --get|get)
            key="$2"
            # ENV override
            env_key="$(normalize_key "$key")"
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
            printf '%s\n' "$writekey=$value" >> "$tmpfile"
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
                # ENV override
                env_key="$(normalize_key "$key")"
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
                    if grep -qvE '^(#|[^=]+=[^\n]*|[[:space:]]*)$' "$GIV_CONFIG_FILE"; then
                        printf '%s\n' "Malformed config" >&2
                        return 1
                    fi
                fi
                val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                if [ -z "$val" ]; then
                    givkey="$(normalize_key "$key")"
                    val=$(grep -E "^$givkey=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                fi
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
                printf '%s\n' "$writekey=$value" >> "$tmpfile"
                mv "$tmpfile" "$GIV_CONFIG_FILE"
            fi
            ;;
    esac
}

giv_config "$@"
