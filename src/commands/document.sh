#!/bin/bash
# -------------------------------------------------------------------
# document.sh: A script to generate documents using AI prompts
# -------------------------------------------------------------------

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"

# Allow test harness to inject mock functions (for bats)
if [ -n "${GIV_TEST_MOCKS:-}" ] && [ -f "${GIV_TEST_MOCKS:-}" ]; then
  . "$GIV_TEST_MOCKS"
fi

# Set defaults for revision and pathspec if not provided
GIV_REVISION="${GIV_REVISION:---current}"
GIV_PATHSPEC="${GIV_PATHSPEC:-}"
export GIV_REVISION
export GIV_PATHSPEC

# Parse arguments for the document subcommand
parse_document_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --prompt-file)
                shift
                export GIV_PROMPT_FILE="$1"
                ;;
            --revision)
                shift
                export GIV_REVISION="$1"
                ;;
            --pathspec)
                shift
                export GIV_PATHSPEC="$1"
                ;;
            --output-file)
                shift
                export GIV_OUTPUT_FILE="$1"
                ;;
            *)
                echo "Error: Unknown option '$1' for document subcommand." >&2
                return 1
                ;;
        esac
        shift
    done

    # Set defaults if not provided
    export GIV_REVISION="${GIV_REVISION:---current}"
    export GIV_PATHSPEC="${GIV_PATHSPEC:-}"  # Default to empty pathspec

    # Validate required options
    if [ -z "${GIV_PROMPT_FILE:-}" ]; then
        echo "Error: --prompt-file is required for the document subcommand." >&2
        return 1
    fi

    return 0
}

# Function to generate documents based on a prompt template
cmd_document() {
    # Use environment variables set by unified parser
    prompt_tpl="${GIV_PROMPT_FILE:-}"
    revision="${GIV_REVISION:---current}"
    pathspec="${GIV_PATHSPEC:-}"
    out="${GIV_OUTPUT_FILE:-}"
    temp="${GIV_TEMPERATURE:-0.9}"
    ctx="${GIV_CONTEXT_WINDOW:-32768}"
    
    # Debug: Log environment variables
    print_debug "GIV_PROMPT_FILE: ${GIV_PROMPT_FILE}"
    print_debug "GIV_REVISION: ${GIV_REVISION}"
    print_debug "GIV_PATHSPEC: ${GIV_PATHSPEC}"
    print_debug "GIV_OUTPUT_FILE: ${GIV_OUTPUT_FILE}"
    print_debug "GIV_TEMPERATURE: ${GIV_TEMPERATURE}"
    print_debug "GIV_CONTEXT_WINDOW: ${GIV_CONTEXT_WINDOW}"

    # Validate template exists
    if [ ! -f "${prompt_tpl}" ]; then
        print_error "Template file not found: ${prompt_tpl}"
        exit 1
    fi

    # Derive base name for temp file prefixes
    doc_base=$(basename "${prompt_tpl%.*}")

    # 1) Summarize
    summaries=$(portable_mktemp "${doc_base}_summaries_XXXXXX")
    print_debug "Generating summaries to: ${summaries}"
    summarize_target "${revision}" "${summaries}" "${pathspec}"

    # Bail if no summaries
    if [ ! -f "${summaries}" ]; then
        print_error "Error: No summaries generated for ${revision}."
        exit 1
    fi

    # 2) Build prompt
    prompt_tmp=$(portable_mktemp "${doc_base}_prompt_XXXXXX")
    title=$(get_project_title "${summaries}")
    current_version="$(get_metadata_value "version" --current)"

    print_debug "Building prompt from ${prompt_tpl} using ${summaries}"
    build_prompt \
        --project-title "${title}" \
        --version "${current_version}" \
        --template "${prompt_tpl}" \
        --summary "${summaries}" \
        >"${prompt_tmp}"

    print_debug "Built prompt file: ${prompt_tmp}"

    # 3) Generate final document
    if [ -n "${ctx}" ]; then
        generate_from_prompt "${prompt_tmp}" "${out}" "${temp}" "${ctx}"
    else
        generate_from_prompt "${prompt_tmp}" "${out}" "${temp}"
    fi
}

# Main entry point for the script
cmd_document
