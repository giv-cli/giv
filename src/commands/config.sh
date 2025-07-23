#!/bin/sh
# giv-config.sh: Git-style config manager for .giv/config

set -eu

: "${GIV_HOME:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.giv}"
: "${GIV_CONFIG_FILE:=${GIV_HOME}/config}"


# If called as 'giv.sh config ...', shift off the 'config' argument
if [ "$1" = "config" ]; then
    shift
fi

giv_config() {
    cmd="$1"
    case "$cmd" in
        --list|list)
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                echo "config file not found" >&2
                return 1
            fi
            # Check for malformed lines
            if [ -s "$GIV_CONFIG_FILE" ]; then
                if grep -qvE '^[^=]+=[^\n]*$' "$GIV_CONFIG_FILE"; then
                    echo "Malformed config" >&2
                    return 1
                fi
            fi
            # Convert GIV_... keys to user keys for output
            while IFS= read -r line; do
                case "$line" in
                    GIV_*)
                        # Convert GIV_FOO_BAR to foo.bar
                        key="$(echo "$line" | sed -E 's/^GIV_([A-Z0-9_]+)=.*/\1/' | tr 'A-Z' 'a-z' | tr '_' '.')"
                        value="${line#*=}"
                        echo "$key=$value"
                        ;;
                    *=*)
                        echo "$line"
                        ;;
                esac
            done < "$GIV_CONFIG_FILE"
            ;;
        --get|get)
            key="$2"
            # ENV override
            env_key="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
            eval "env_val=\"\${$env_key-}\""
            if [ -n "$env_val" ]; then
                printf '%s\n' "$env_val"
                return 0
            fi
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                echo "config file not found" >&2
                return 1
            fi

            # Try user key first, then GIV_ key
            val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
            if [ -z "$val" ]; then
                givkey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
                val=$(grep -E "^$givkey=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
            fi
            printf '%s\n' "$val"
            ;;
        --unset|unset)
            key="$2"
            if [ ! -f "$GIV_CONFIG_FILE" ]; then
                echo "config file not found" >&2
                return 1
            fi
            tmpfile=$(mktemp)
            givkey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
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
            givkey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
            grep -v -E "^($key|$givkey)=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
            # Always write in GIV_... format
            writekey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
            echo "$writekey=$value" >> "$tmpfile"
            mv "$tmpfile" "$GIV_CONFIG_FILE"
            ;;
        -*|help)
            echo "Unknown option: $cmd" >&2
            echo "Usage: giv config [list|get key|set key value|unset key|key [value]]" >&2
            return 1
            ;;
        *)
            key="$1"
            value="${2:-}"
            if [ -z "$value" ]; then
                # ENV override
                env_key="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
                eval "env_val=\"\${$env_key-}\""
                if [ -n "$env_val" ]; then
                    printf '%s\n' "$env_val"
                    return 0
                fi
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    echo "config file not found" >&2
                    return 1
                fi
                if [ -s "$GIV_CONFIG_FILE" ]; then
                    if grep -qvE '^[^=]+=[^\n]*$' "$GIV_CONFIG_FILE"; then
                        echo "Malformed config" >&2
                        return 1
                    fi
                fi
                val=$(grep -E "^$key=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                if [ -z "$val" ]; then
                    givkey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
                    val=$(grep -E "^$givkey=" "$GIV_CONFIG_FILE" | cut -d'=' -f2-)
                fi
                printf '%s\n' "$val"
            else
                mkdir -p "$GIV_HOME"
                if [ ! -f "$GIV_CONFIG_FILE" ]; then
                    touch "$GIV_CONFIG_FILE"
                fi
                tmpfile=$(mktemp)
                givkey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
                grep -v -E "^($key|$givkey)=" "$GIV_CONFIG_FILE" | grep -v '^$' > "$tmpfile"
                # Always write in GIV_... format
                writekey="GIV_$(echo "$key" | tr '[:lower:]' '[:upper:]' | tr '.' '_')"
                echo "$writekey=$value" >> "$tmpfile"
                mv "$tmpfile" "$GIV_CONFIG_FILE"
            fi
            ;;
    esac
}

giv_config "$@"
