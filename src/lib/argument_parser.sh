#!/bin/sh
# argument_parser.sh: Unified argument parsing for giv CLI
# Consolidates all argument parsing logic into a single, maintainable module

# Source system utilities for print_debug function
if [ -n "${GIV_LIB_DIR:-}" ]; then
    . "$GIV_LIB_DIR/system.sh"
else
    # Fallback for standalone testing
    SCRIPT_DIR="$(dirname "$0")"
    if [ -f "$SCRIPT_DIR/../system.sh" ]; then
        . "$SCRIPT_DIR/../system.sh"
    else
        # Minimal print_debug fallback
        print_debug() {
            if [ "${GIV_DEBUG:-}" = "true" ]; then
                printf 'DEBUG: %s\n' "$*" >&2
            fi
        }
    fi
fi

# Global option definitions - defines all supported options and their properties
# Format: option_name:type:env_var:description
# Types: flag (no argument), value (requires argument)
GLOBAL_OPTIONS="
help:flag:GIV_HELP:Show help and exit
version:flag:GIV_VERSION:Show version and exit  
verbose:flag:GIV_DEBUG:Enable debug/trace output
dry-run:flag:GIV_DRY_RUN:Preview only; don't write any files
config-file:value:GIV_CONFIG_FILE:Shell config file to source before running
todo-files:value:GIV_TODO_FILES:Pathspec for files to scan for TODOs
todo-pattern:value:GIV_TODO_PATTERN:Regex to match TODO lines
version-file:value:GIV_PROJECT_VERSION_FILE:Pathspec of file(s) to inspect for version bumps
version-pattern:value:GIV_PROJECT_VERSION_PATTERN:Custom regex to identify version strings
model:value:GIV_API_MODEL:Specify the local or remote model name
api-model:value:GIV_API_MODEL:Remote model name (alias for --model)
api-url:value:GIV_API_URL:Remote API endpoint URL
api-key:value:GIV_API_KEY:API key for remote mode
output-mode:value:GIV_OUTPUT_MODE:auto, prepend, append, update, none
output-version:value:GIV_OUTPUT_VERSION:Override section header/tag name
output-file:value:GIV_OUTPUT_FILE:Destination file
prompt-file:value:GIV_PROMPT_FILE:Markdown prompt template to use
list:flag:GIV_LIST:List configuration values
"

# Valid subcommands
VALID_SUBCOMMANDS="message msg summary changelog release-notes announcement document doc init config available-releases update help version"

# Parse a single option and set the corresponding environment variable
# Args: $1=option_name $2=option_value (if applicable) $3=option_type
parse_option() {
    local option_name="$1"
    local option_value="$2" 
    local option_type="$3"
    local env_var="$4"
    
    case "$option_type" in
        flag)
            export "${env_var}=true"
            print_debug "Set flag: $env_var=true"
            ;;
        value)
            if [ -z "$option_value" ]; then
                echo "Error: Option --$option_name requires a value" >&2
                return 1
            fi
            # Handle special cases for path options
            case "$option_name" in
                config-file)
                    # Convert relative paths to absolute
                    if [ "${option_value#/}" = "$option_value" ]; then
                        option_value="$(pwd)/$option_value"
                    fi
                    ;;
            esac
            export "${env_var}=$option_value"
            print_debug "Set value: $env_var=$option_value"
            ;;
        *)
            echo "Error: Unknown option type: $option_type" >&2
            return 1
            ;;
    esac
}

# Find option definition by name
# Returns: type:env_var:description
find_option_def() {
    local option_name="$1"
    echo "$GLOBAL_OPTIONS" | grep "^${option_name}:" | head -1 | cut -d: -f2-
}

# Parse global arguments (before subcommand)
# Sets: GIV_SUBCMD and various GIV_* environment variables
# Args: "$@" - all command line arguments
parse_global_args() {
    GIV_SUBCMD=""
    
    # Check if no arguments provided
    if [ $# -eq 0 ]; then
        echo "Error: No arguments provided." >&2
        export GIV_SUBCMD="help"
        return 1
    fi
    
    # Parse arguments until we find a subcommand
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help|help)
                export GIV_SUBCMD="help"
                return 0
                ;;
            -v|--version)
                export GIV_SUBCMD="version" 
                return 0
                ;;
            --*)
                # Parse long option
                option_name="${1#--}"
                option_def="$(find_option_def "$option_name")"
                
                if [ -z "$option_def" ]; then
                    echo "Error: Unknown option: $1" >&2
                    return 1
                fi
                
                option_type="$(echo "$option_def" | cut -d: -f1)"
                env_var="$(echo "$option_def" | cut -d: -f2)"
                
                if [ "$option_type" = "value" ]; then
                    if [ $# -lt 2 ]; then
                        echo "Error: Option $1 requires a value" >&2
                        return 1
                    fi
                    parse_option "$option_name" "$2" "$option_type" "$env_var" || return 1
                    shift 2
                else
                    parse_option "$option_name" "" "$option_type" "$env_var" || return 1
                    shift
                fi
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                return 1
                ;;
            *)
                # First non-option argument should be subcommand
                if echo " $VALID_SUBCOMMANDS " | grep -q " $1 "; then
                    export GIV_SUBCMD="$1"
                else
                    # Unknown subcommand - let dispatcher handle it
                    export GIV_SUBCMD="$1"
                fi
                shift
                break
                ;;
        esac
    done
    
    # Load config file if specified
    if [ -n "${GIV_CONFIG_FILE:-}" ] && [ -f "$GIV_CONFIG_FILE" ]; then
        print_debug "Loading config file: $GIV_CONFIG_FILE"
        . "$GIV_CONFIG_FILE" || {
            echo "Error: Failed to load config file: $GIV_CONFIG_FILE" >&2
            return 1
        }
    fi
    
    # Remaining arguments will be handled by main parse_arguments function
    
    return 0
}

# Parse subcommand arguments (after subcommand name)
# Sets: GIV_REVISION, GIV_PATHSPEC, and any remaining option overrides
# Args: "$@" - remaining arguments after subcommand
parse_subcommand_args() {
    # Set defaults
    GIV_REVISION="${GIV_REVISION:---current}"
    GIV_PATHSPEC="${GIV_PATHSPEC:-}"
    local positional_args=""
    
    while [ $# -gt 0 ]; do
        case "$1" in
            --current|--cached|--staged)
                if [ "$1" = "--staged" ]; then
                    GIV_REVISION="--cached"
                else
                    GIV_REVISION="$1"
                fi
                shift
                ;;
            --*)
                # Parse any remaining options
                option_name="${1#--}"
                option_def="$(find_option_def "$option_name")"
                
                if [ -n "$option_def" ]; then
                    option_type="$(echo "$option_def" | cut -d: -f1)"
                    env_var="$(echo "$option_def" | cut -d: -f2)"
                    
                    if [ "$option_type" = "value" ]; then
                        if [ $# -lt 2 ]; then
                            echo "Error: Option $1 requires a value" >&2
                            return 1
                        fi
                        parse_option "$option_name" "$2" "$option_type" "$env_var" || return 1
                        shift 2
                    else
                        parse_option "$option_name" "" "$option_type" "$env_var" || return 1
                        shift
                    fi
                else
                    echo "Error: Unknown option: $1" >&2
                    return 1
                fi
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                return 1
                ;;
            *)
                # Positional argument - could be revision or pathspec
                if [ -z "$positional_args" ]; then
                    # First positional arg - check if it's a git revision
                    if echo "$1" | grep -q '\.\.'; then
                        # Range syntax
                        if git rev-list "$1" >/dev/null 2>&1; then
                            GIV_REVISION="$1"
                        else
                            echo "Error: Invalid git range: $1" >&2
                            return 1
                        fi
                    elif git rev-parse --verify "$1" >/dev/null 2>&1; then
                        # Valid commit
                        GIV_REVISION="$1"
                    else
                        # Not a git revision, treat as pathspec
                        positional_args="$1"
                    fi
                else
                    # Additional positional args are pathspecs
                    positional_args="$positional_args $1"
                fi
                shift
                ;;
        esac
    done
    
    # Set pathspec from positional args
    if [ -n "$positional_args" ]; then
        GIV_PATHSPEC="$(echo "$positional_args" | sed 's/^ *//' | sed 's/ *$//')"
    fi
    
    export GIV_REVISION GIV_PATHSPEC
    
    print_debug "Parsed revision: $GIV_REVISION"
    print_debug "Parsed pathspec: $GIV_PATHSPEC"
    
    return 0
}

# Main entry point - parse all arguments
# Args: "$@" - all command line arguments  
parse_arguments() {
    # Store original arguments
    ORIG_ARGS="$*"
    
    # Parse global options and identify subcommand
    if ! parse_global_args "$@"; then
        return 1
    fi
    
    # Don't parse subcommand args for help/version/config/init
    case "${GIV_SUBCMD:-}" in
        help|version|config|init)
            return 0
            ;;
    esac
    
    # Now parse remaining arguments by reconstructing them after subcommand extraction
    # Find where subcommand appears in original args and get everything after it
    set -- $ORIG_ARGS
    subcommand_found=false
    while [ $# -gt 0 ]; do
        if [ "$subcommand_found" = "true" ]; then
            # We found the subcommand, now parse remaining args
            if ! parse_subcommand_args "$@"; then
                return 1
            fi
            break
        elif [ "$1" = "${GIV_SUBCMD}" ]; then
            subcommand_found=true
            shift
        else
            shift
        fi
    done
    
    return 0
}

# Validate required options for specific subcommands
validate_subcommand_requirements() {
    case "${GIV_SUBCMD:-}" in
        document)
            if [ -z "${GIV_PROMPT_FILE:-}" ]; then
                echo "Error: --prompt-file is required for the document subcommand" >&2
                return 1
            fi
            ;;
    esac
    return 0
}