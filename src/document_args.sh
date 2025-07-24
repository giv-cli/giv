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
            --dry-run)
                GIV_DRY_RUN="true"
                export GIV_DRY_RUN
                ;;
            --api-url)
                GIV_API_URL="$2"
                export GIV_API_URL
                shift
                ;;
            --api-key)
                GIV_API_KEY="$2"
                export GIV_API_KEY
                shift
                ;;
            --api-model)
                GIV_API_MODEL="$2"
                export GIV_API_MODEL
                shift
                ;;
            --output-file)
                GIV_OUTPUT_FILE="$2"
                export GIV_OUTPUT_FILE
                shift
                ;;
            --output-version)
                GIV_OUTPUT_VERSION="$2"
                export GIV_OUTPUT_VERSION
                shift
                ;;
            --model)
                GIV_API_MODEL="$2"
                export GIV_API_MODEL
                shift
                ;;
            --version-file)
                GIV_PROJECT_VERSION_FILE="$2"
                export GIV_PROJECT_VERSION_FILE
                shift
                ;;
            --version-pattern)
                GIV_PROJECT_VERSION_PATTERN="$2"
                export GIV_PROJECT_VERSION_PATTERN
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
