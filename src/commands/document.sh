#!/bin/bash
# -------------------------------------------------------------------
# document.sh: A script to generate documents using AI prompts
# -------------------------------------------------------------------

# Load initialization and shared functions
. "$GIV_LIB_DIR/init.sh"

# Allow test harness to inject mock functions (for bats)
if [ -n "$GIV_TEST_MOCKS" ] && [ -f "$GIV_TEST_MOCKS" ]; then
  . "$GIV_TEST_MOCKS"
fi
# Function to generate documents based on a prompt template
cmd_document() {
    # Use environment variables set by unified parser
    prompt_tpl="${GIV_PROMPT_FILE:-}"
    revision="${GIV_REVISION:---current}"
    pathspec="${GIV_PATHSPEC:-}"
    out="${GIV_OUTPUT_FILE:-}"
    temp="${GIV_TEMPERATURE:-0.9}"
    ctx="${GIV_CONTEXT_WINDOW:-32768}"

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
