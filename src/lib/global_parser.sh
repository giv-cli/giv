#!/bin/sh

# Global Argument Parser for giv CLI
# Handles global options and subcommand detection

# Parse global arguments and leave remaining args in "$@"
parse_global_arguments() {
    subcommand=""
    remaining_args=""
    
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                subcommand="help"
                shift
                break
                ;;
            -v|--version)
                subcommand="version" 
                shift
                break
                ;;
            --verbose)
                export GIV_VERBOSE="true"
                export GIV_DEBUG="true"
                shift
                ;;
            --dry-run)
                export GIV_DRY_RUN="true"
                shift
                ;;
            --config-file)
                shift
                if [ "$#" -gt 0 ]; then
                    export GIV_CONFIG_FILE="$1"
                    shift  # Skip the config file value
                fi
                ;;
            *)
                # This is the subcommand
                subcommand="$1"
                shift
                # Collect remaining arguments, filtering out any more global options
                while [ "$#" -gt 0 ]; do
                    case "$1" in
                        --verbose)
                            export GIV_VERBOSE="true"
                            export GIV_DEBUG="true"
                            shift
                            ;;
                        --dry-run)
                            export GIV_DRY_RUN="true"
                            shift
                            ;;
                        --config-file)
                            shift
                            if [ "$#" -gt 0 ]; then
                                export GIV_CONFIG_FILE="$1"
                                shift
                            fi
                            ;;
                        *)
                            # Add to remaining arguments, quoting values with spaces but not pathspecs
                            case "$1" in
                                :\(*\)*)
                                    # Git pathspecs starting with :( - don't quote these as they have special syntax
                                    if [ -z "$remaining_args" ]; then
                                        remaining_args="$1"
                                    else
                                        remaining_args="$remaining_args $1"
                                    fi
                                    ;;
                                *' '*)
                                    # Quote arguments containing spaces
                                    if [ -z "$remaining_args" ]; then
                                        remaining_args="'$1'"
                                    else
                                        remaining_args="$remaining_args '$1'"
                                    fi
                                    ;;
                                *)
                                    # Regular arguments
                                    if [ -z "$remaining_args" ]; then
                                        remaining_args="$1"
                                    else
                                        remaining_args="$remaining_args $1"
                                    fi
                                    ;;
                            esac
                            shift
                            ;;
                    esac
                done
                break
                ;;
        esac
    done
    
    # Set default subcommand if none provided
    if [ -z "$subcommand" ]; then
        subcommand="message"
    fi
    
    export GIV_SUBCOMMAND="$subcommand"
    export GIV_REMAINING_ARGS="$remaining_args"
}

# Dispatch to the appropriate subcommand script
execute_subcommand() {
    subcommand_script="${SRC_DIR}/commands/${GIV_SUBCOMMAND}.sh"

    if [ ! -f "$subcommand_script" ]; then
        echo "Error: Unknown subcommand '$GIV_SUBCOMMAND'." >&2
        echo "Use -h or --help for usage information." >&2
        exit 1
    fi

    # Debug: Log the subcommand and arguments only if debug is enabled
    if [ "${GIV_DEBUG:-}" = "true" ]; then
        echo "Executing subcommand: $GIV_SUBCOMMAND" >&2
        echo "With arguments: ${GIV_REMAINING_ARGS:-}" >&2
    fi

    # Forward remaining arguments to the subcommand script, properly handling spaces
    if [ -n "${GIV_REMAINING_ARGS:-}" ]; then
        # For pathspecs and complex arguments, bypass eval entirely
        case "$GIV_REMAINING_ARGS" in
            *':(exclude)'*|*':(include)'*|*':(top)'*|*':(literal)'*)
                # Git pathspecs with magic signatures - use exec directly, no quoting
                exec "$subcommand_script" $GIV_REMAINING_ARGS
                ;;
            *)
                # Regular arguments may need eval for proper quoting
                eval "exec \"$subcommand_script\" $GIV_REMAINING_ARGS"
                ;;
        esac
    else
        exec "$subcommand_script"
    fi
}
