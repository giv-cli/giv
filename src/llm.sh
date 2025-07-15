
# json_escape - Reads stdin and outputs JSON-escaped string (with surrounding quotes)
#
# This function handles the following characters:
#   - backslash (\)
#   - double quote (" )
#   - newlines (\n) replaced with \n using tr
#   - tabs (\t)
#   - carriage returns (\r)
#   - form feeds (\f)
#   - backspaces (\b)
#
# Usage: echo "input string" | json_escape
json_escape() {
    # Reads stdin, outputs JSON-escaped string (with surrounding quotes)
    # Handles: backslash, double quote, newlines, tabs, carriage returns, form feeds, backspaces
    # Newlines are replaced with \n using tr
    sed -e 's/\\/\\\\/g' \
        -e 's/"/\\"/g' \
        -e 's/\r/\\r/g' \
        -e 's/\t/\\t/g' \
        -e 's/\f/\\f/g' \
        -e 's/\b/\\b/g' |
        awk 'BEGIN{printf "\""} {printf "%s", $0} END{print "\""}'
}

# extract_content_from_response - Extracts content from a JSON string.
#
# Usage:
#   extract_content_from_response "$json_string"
#
# Parameters:
#   $1 (json) - The JSON string containing the "content" property to be extracted.
#
# Description:
#   This function extracts all lines from the "content" property of a given JSON string,
#   handling multi-line content and interpreting backslash-escapes into real characters.
#   It uses `awk` to parse the JSON string and extract the content, then processes it
#   to replace escape sequences with their corresponding characters.
#
# Example:
#   json='{"content": "This is a line.\nThis is another line."}'
#   extract_content_from_response "$json"
extract_content_from_response() {
    # Usage: extract_content_from_response "$json_string"
    json=$1

    # 1) Extract all lines from the "content" property (handles multi-line content)
    raw=$(printf '%s' "$json" | awk '
    BEGIN { in_content=0; esc=""; val="" }
    {
        line = $0
        if (!in_content) {
            # Look for "content":
            m = match(line, /"content"[[:space:]]*:[[:space:]]*"/)
            if (m) {
                in_content=1
                # Start after the opening quote
                start = RSTART + RLENGTH
                val = substr(line, start)
                # Check if closing quote is on this line
                i = 1; esc=0; out=""
                while (i <= length(val)) {
                    c = substr(val,i,1)
                    if (c == "\\" && esc == 0) {
                        esc = 1
                        out = out c
                    } else if (c == "\"" && esc == 0) {
                        print out
                        exit
                    } else {
                        esc = 0
                        out = out c
                    }
                    i++
                }
                print out
            }
        } else {
            # Already inside content, keep accumulating
            i = 1; esc=0; out=""
            while (i <= length(line)) {
                c = substr(line,i,1)
                if (c == "\\" && esc == 0) {
                    esc = 1
                    out = out c
                } else if (c == "\"" && esc == 0) {
                    print out
                    exit
                } else {
                    esc = 0
                    out = out c
                }
                i++
            }
            print out
        }
    }
    ')

    # 2) interpret backslash-escapes (\n, \", \\) into real characters:
    printf '%s' "$raw" | awk '
    {
        gsub(/\\\\/, "\\", $0)
        gsub(/\\"/, "\"", $0)
        gsub(/\\n/, "\n", $0)
        gsub(/\\r/, "\r", $0)
        gsub(/\\t/, "\t", $0)
        gsub(/\\b/, "\b", $0)
        gsub(/\\f/, "\f", $0)
        print
    }'
}

generate_remote() {
    content=$(cat "$1")

    # Escape for JSON (replace backslash, double quote, and control characters)
    # Use json_escape to safely encode the prompt as a JSON string
    escaped_content=$(printf "%s" "${content}" | json_escape)

    # shellcheck disable=SC2154
    body=$(printf '{"model":"%s","messages":[{"role":"user","content":%s}],"max_completion_tokens":8192}' \
        "${api_model}" "${escaped_content}")

    # shellcheck disable=SC2154
    response=$(curl -s -X POST "${api_url}" \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "${body}")

    if [ "$debug" = "true" ]; then
        echo "Response from remote API:" >&2
        echo "${response}" >&2
        #echo "${response}" >> "response.json"
    fi

    # Extract the content field from the response
    result=$(extract_content_from_response "${response}")

    #print_debug "Parsed response:$result"
    echo "${result}"
}

run_local() {
    # Backup original values of OLLAMA_TEMPERATURE and OLLAMA_NUM_CTX
    orig_ollama_temperature="${OLLAMA_TEMPERATURE:-}"
    orig_ollama_num_ctx="${OLLAMA_NUM_CTX:-}"

    export OLLAMA_TEMPERATURE="${3:-0.9}"
    export OLLAMA_NUM_CTX="${4:-32768}"

    if [ "$debug" = "true" ]; then
        # shellcheck disable=SC2154
        ollama run "${model}" --verbose <"$1"
    else
        ollama run "${model}" <"$1"
    fi

    # Reset to original values after the command completes
    export OLLAMA_TEMPERATURE="${orig_ollama_temperature}"
    export OLLAMA_NUM_CTX="${orig_ollama_num_ctx}"
}

# The `generate_response` function generates a response based on the specified mode.
#
# Parameters:
#   $1 - Path to the input file.
#   $2 (optional) - Mode for generating the response. Possible values are 'remote', 'none', or any other value for local generation.
#   $3 (optional) - Temperature setting for the model, if applicable.
#   $4 (optional) - Context window size for the model, if applicable.
#
# Description:
#   The function determines the mode of operation based on the second argument ($2), falling back to the `model_mode` environment variable, and finally defaulting to 'auto'.
#   If debugging is enabled (via the `debug` environment variable), it prints a debug message indicating the chosen mode.
#
#   Depending on the mode:
#     - 'remote': Calls the `generate_remote` function with the input file path as an argument, along with temperature and context window size if provided.
#     - 'none': Outputs the content of the input file directly using `cat`.
#     - Any other value: Calls the `run_local` function with the input file path as an argument, along with temperature and context window size if provided.
generate_response() {
    gen_mode="${2:-$model_mode:-auto}"
    temp="${3:-0.5}"         # Default to a neutral temperature of 0.5
    ctx_window="${4:-32768}" # Default context window size

    print_debug "Generating response using $gen_mode mode with temperature=$temp and context window size=$ctx_window"

    case ${gen_mode} in
    remote)
        generate_remote "$1" "$temp" "$ctx_window"
        ;;
    none)
        cat "$1"
        ;;
    *)
        run_local "$1" "$temp" "$ctx_window"
        ;;
    esac
}


# Replaces every “[NAME]” in stdin with the contents of
# the environment variable GIV_TOKEN_NAME (if set).
#
# Usage:
#   export GIV_TOKEN_FOO="multi
#   line
#   text"
#   replace_tokens < template.md > output.md
replace_tokens() {
    summary_file=$1
    shift

    awk -v summary_file="$summary_file" '
    # ----- helpers --------------------------------------------------------
    function emit_summary(   l) {
        if (summary_file_read || summary_file == "") return
        while ((getline l < summary_file) > 0) print l "\n"
        close(summary_file)
        summary_file_read = 1
    }

    # ----- build the map from env ----------------------------------------
    BEGIN {
        ORS = ""
        for (v in ENVIRON) {
            if (substr(v,1,10) == "GIV_TOKEN_" && v != "GIV_TOKEN_SUMMARY") {
                name = substr(v,11)          # strip the prefix
                map[name] = ENVIRON[v]
            }
        }
    }

    # ----- main loop ------------------------------------------------------
    {
        if (index($0, "[SUMMARY]")) {
            # Split the line on the placeholder so we can inject the diff
            n = split($0, parts, /\[SUMMARY\]/)
            for (i = 1; i <= n; i++) {
                fragment = parts[i]
                for (k in map) gsub("\\[" k "\\]", map[k], fragment)
                printf "%s", fragment
                if (i < n) emit_summary()
            }
            print "\n"
        } else {
            line = $0
            for (k in map) gsub("\\[" k "\\]", map[k], line)
            print line "\n"
        }
    }
    ' "$@"
}

# build_prompt: fill a prompt template with tokens and diff content
#
# Usage:
#   build_prompt \
#     [--project-title X] \
#     [--version V] \
#     [--example E] \
#     [--rules R] \
#     --template TEMPLATE_FILE \
#     --summary SUMMARY_FILE
#
# Exports:
#   GIV_TOKEN_PROJECT_TITLE, GIV_TOKEN_VERSION,
#   GIV_TOKEN_EXAMPLE, GIV_TOKEN_RULES, GIV_TOKEN_SUMMARY
#
# Reads TEMPLATE_FILE, appends instructions, then pipes through replace_tokens
# using SUMMARY_FILE as the summary source.
build_prompt() {
    # default tokens
    project_title="$(get_project_title)"
    version="${output_version:-${GIV_TOKEN_VERSION:-}}"
    example=""
    rules=""
    template_file=""
    summary_file=""

    # resolve version if unset or 'auto'
    if [ -z "${version}" ] || [ "${version}" = "auto" ]; then
        print_debug "No version set or version is 'auto', trying to find it from version file"
        version_file="$(find_version_file)"
        version="$(get_version_info --current "${version_file:-}")"
    fi

    # parse named options
    while [ $# -gt 0 ]; do
        case "$1" in
        --project-title)
            project_title=$2
            shift 2
            ;;
        --version)
            version=$2
            shift 2
            ;;
        --example)
            example=$2
            shift 2
            ;;
        --rules)
            rules=$2
            shift 2
            ;;
        --template)
            template_file=$2
            shift 2
            ;;
        --summary)
            summary_file=$2
            shift 2
            ;;
        *)
            printf 'unknown option: %s\n' "$1" >&2
            return 1
            ;;
        esac
    done

    # require both template and diff
    if [ -z "${template_file}" ]; then
        printf 'Error: --template TEMPLATE_FILE is required\n' >&2
        return 1
    fi
    if [ -z "${summary_file}" ]; then
        printf 'Error: --summary SUMMARY_FILE is required\n' >&2
        return 1
    fi

    print_debug "Building prompt from template: ${template_file}, using diff file: ${summary_file}"

    # validate files exist
    if [ ! -f "${template_file}" ]; then
        printf 'template file not found: %s\n' "${template_file}" >&2
        return 1
    fi
    if [ ! -f "${summary_file}" ]; then
        printf 'diff file not found: %s\n' "${summary_file}" >&2
        return 1
    fi

    # export token env vars for replace_tokens
    unset GIV_TOKEN_SUMMARY
    export GIV_TOKEN_PROJECT_TITLE="${project_title:-${GIV_TOKEN_PROJECT_TITLE}}"
    export GIV_TOKEN_VERSION="${version:-${GIV_TOKEN_VERSION}}"
    export GIV_TOKEN_EXAMPLE="${example:-${GIV_TOKEN_EXAMPLE}}"
    export GIV_TOKEN_RULES="${rules:-${GIV_TOKEN_RULES}}"

    # combine template + instructions, then replace tokens using diff as summary
    {
        cat "${template_file}"
        printf '\nOutput just the final content—no extra commentary or code fencing. '
        printf 'Use only information contained in this prompt and the summaries provided above.\n'
    } | replace_tokens "${summary_file}"

    return
}

# Function to generate a response from a prompt file and write it to an output file.
#
# Parameters:
#   $1 - Path to the prompt file (required).
#   $2 - Path to the response output file (required).
#   $3 - Generation mode. Defaults to GIV_MODEL_MODE or 'auto' if not set.
#   $4 - Temperature for response generation. Default is 0.9.
#   $5 - Context window size for response generation. Default is 32768.
#
# The function performs the following steps:
# 1) Invokes the AI to generate a response based on the prompt file and parameters.
# 2) If in dry-run mode or if no output file is specified, prints the response and exits.
# 3) Otherwise, writes the generated response to the specified output file.
#
# Returns:
#   0 - Success
#   1 - Error (e.g., generate_response failed or unable to write to output file)
generate_from_prompt() {
    prompt_file="$1"
    response_output_file="$2"
    gen_mode="${3:-${GIV_MODEL_MODE:-${model_mode:-auto}}}"
    temperature="${4:-0.9}"      # Default value for temperature
    context_window="${5:-32768}" # Default value for context window

    print_debug "Prompt file: $prompt_file"
    print_debug "Output file: $response_output_file"
    print_debug "Model mode: $gen_mode"

    # 1) Invoke the AI
    if ! res=$(generate_response "$prompt_file" "$gen_mode" "$temperature" "$context_window"); then
        printf 'Error: generate_response failed (mode=%s)\n' "$gen_mode" >&2
        exit 1
    fi

    # 2) Dry‐run?  Just print and exit
    if [ "${dry_run:-}" = "true" ] || [ -z "${response_output_file}" ]; then
        printf '%s\n' "$res"
        return 0
    fi

    # 3) Otherwise, write (create or overwrite) the output file
    if printf '%s\n' "$res" >"$response_output_file"; then
        print_info "Response written to $response_output_file"
        return 0
    else
        printf 'Error: Failed to write response to %s\n' "$response_output_file" >&2
        exit 1
    fi
}