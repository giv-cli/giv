#!/bin/sh
# document_args.sh: Shared argument parsing for document-related subcommands

parse_document_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --todo-files)
                TODO_FILES="$2"
                shift
                ;;
            --todo-pattern)
                TODO_PATTERN="$2"
                shift
                ;;
            --output-mode)
                OUTPUT_MODE="$2"
                shift
                ;;
            --prompt-file)
                PROMPT_FILE="$2"
                shift
                ;;
            *)
                POSITIONAL_ARGS="${POSITIONAL_ARGS:-} $1"
                ;;
        esac
        shift
    done
    export TODO_FILES TODO_PATTERN OUTPUT_MODE PROMPT_FILE POSITIONAL_ARGS
}
