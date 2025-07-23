#!/bin/sh
# giv-config.sh: Git-style config manager for .giv/config

set -eu

: "${GIV_HOME:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.giv}"
: "${GIV_CONFIG_FILE:=${GIV_HOME}/config}"


# If called as 'giv.sh config ...', shift off the 'config' argument
if [ "$1" = "config" ]; then
    shift
fi

mkdir -p "$GIV_HOME" || exit 1
touch "$GIV_CONFIG_FILE" || exit 1

giv_config() {
    case "$1" in
        --list) # List all configuration values
            cat "$GIV_CONFIG_FILE"
            ;;
        --get) # Get a specific configuration value
            key="$2"
            grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-
            ;;
        --unset) # Remove a specific configuration value
            key="$2"
            tmpfile=$(mktemp)
            grep -v -E "^$key=" "$GIV_CONFIG_FILE" > "$tmpfile"
            mv "$tmpfile" "$GIV_CONFIG_FILE"
            ;;
        --set) # Set a specific configuration value
            key="$2"
            value="$3"
            echo "$key=$value" >> "$GIV_CONFIG_FILE"
            ;;
        -*)
            echo "Unknown option: $1" >&2
            echo "Usage: giv config [--list] [--get key] [--unset key] [--set key value] [key] [value]" >&2
            return 1
            ;;
        *)
            key="$1"
            value="$2"
            # Convert key to .env format: dots to underscores, uppercase, prefix GIV_
            env_key="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
            if [ -z "$value" ]; then
                # Shorthand get
                grep -E "^$env_key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-
            else
                # Properly quote the value for .env (double quotes, escape inner quotes)
                quoted_value=$(printf '%s' "$value" | sed 's/\\/\\\\/g; s/\"/\\\"/g; s/^/\"/; s/$/\"/')
                tmpfile=$(mktemp)
                grep -v -E "^$env_key=" "$GIV_CONFIG_FILE" > "$tmpfile"
                echo "$env_key=$quoted_value" >> "$tmpfile"
                mv "$tmpfile" "$GIV_CONFIG_FILE"
            fi
            ;;
    esac
}

giv_config "$@"
