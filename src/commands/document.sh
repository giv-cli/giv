#!/bin/bash

# -------------------------------------------------------------------
# document.sh: A script to generate documents using AI prompts
# -------------------------------------------------------------------

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"

# Source shared argument parsing for document-related subcommands
. "$GIV_LIB_DIR/document_args.sh"

# Parse arguments specific to changelog
parse_document_args "$@"

# Function to generate documents based on a prompt template
cmd_document() {
    prompt_tpl="${1:-$PROMPT_FILE}"
    revision="${2:---current}"
    pathspec="${3:-}" # New GIV_PATHSPEC argument
    out="${4:-}"
    temp="${5:-0.9}"
    ctx="${6:-32768}"
    shift 6

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
        "$@" >"${prompt_tmp}"

    print_debug "Built prompt file: ${prompt_tmp}"

    # 3) Generate final document
    if [ -n "${ctx}" ]; then
        generate_from_prompt "${prompt_tmp}" "${out}" "${temp}" "${ctx}"
    else
        generate_from_prompt "${prompt_tmp}" "${out}" "${temp}"
    fi
}

# Main entry point for the script
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <prompt_template> [revision] [pathspec] [output_file] [temperature] [context_window] [extra_flags...]"
    exit 1
fi

# Initialize missing variables to resolve lint errors
GIV_LIB_DIR="/path/to/lib"

cmd_document "$@"
