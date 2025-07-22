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

    print_debug "Generating remote response with content: $GIV_API_MODEL"
    # Check required environment variables
    if [ -z "${GIV_API_MODEL}" ] || [ -z "${GIV_API_URL}" ] || [ -z "${GIV_API_KEY}" ]; then
        printf 'Error: Missing required environment variables for remote generation.\n' >&2
        return 1
    fi

    # Escape for JSON (replace backslash, double quote, and control characters)
    # Use json_escape to safely encode the prompt as a JSON string
    escaped_content=$(printf "%s" "${content}" | json_escape)

    # shellcheck disable=SC2154
    body=$(printf '{"model":"%s","messages":[{"role":"user","content":%s}],"max_completion_tokens":8192}' \
        "${GIV_API_MODEL}" "${escaped_content}")

    # shellcheck disable=SC2154
    response=$(curl -s -X POST "${GIV_API_URL}" \
        -H "Authorization: Bearer ${GIV_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${body}")

    if [ "$GIV_DEBUG" = "true" ]; then
        echo "Response from remote API:" >&2
        echo "${response}" >&2
    fi

    # Extract the content field from the response
    result=$(extract_content_from_response "${response}")

    echo "${result}"
}

generate_response() {
    temp="${2:-0.5}"         # Default to a neutral temperature of 0.5
    ctx_window="${3:-32768}" # Default context window size

    print_debug "Generating response with temperature=$temp, context window size=$ctx_window"

    if ! generate_remote "$1" "$temp" "$ctx_window"; then
        print_error "Failed to generate remote response"
        return 1
    fi
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

# replace_metadata: Replaces placeholders in stdin with values from GIV_METADATA_ environment variables.
#
# Usage:
#   replace_metadata < summary_file > output_file
replace_metadata() {
  awk '
    BEGIN {
      ORS = ""
    }
    {
      line = $0
      for (v in ENVIRON) {
        if (v ~ /^GIV_METADATA_/) {
          name = substr(v, 14)
          gsub("\\[" name "\\]", ENVIRON[v], line)
        }
      }
      print line "\n"
    }
  '
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
    project_title="${GIV_METADATA_TITLE:-}"
    version="${output_version:-${GIV_TOKEN_VERSION:-}}"
    example=""
    rules=""
    template_file=""
    summary_file=""

    print_debug "Arguments passed to build_prompt: $*"

    # resolve version if unset or 'auto'
    if [ -z "${version}" ] || [ "${version}" = "auto" ]; then
        print_debug "No version set or version is 'auto', trying to find it from version file"
        version="$(get_project_version --current)"
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
            print_debug "Template file set to: $template_file"
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

    # combine template + instructions, then replace metadata and tokens using diff as summary
    {
        cat "${template_file}"
        printf '\nOutput just the final content—no extra commentary or code fencing. '
        printf 'Use only information contained in this prompt and the summaries provided above.\n'
    }  | replace_tokens "${summary_file}"| replace_metadata "${summary_file}"

    return
}

generate_from_prompt() {
    prompt_file="$1"
    response_output_file="$2"
    temperature="${3:-0.9}"      # Default value for temperature
    context_window="${4:-32768}" # Default value for context window

    print_debug "Prompt file: $prompt_file"
    print_debug "Output file: $response_output_file"

    # 1) Invoke the AI
    if ! res=$(generate_response "$prompt_file" "$temperature" "$context_window"); then
        print_error "Failed to generate_response"
        exit 1
    fi

    # 2) Dry‐run?  Just print and exit
    if [ "${GIV_DRY_RUN:-}" = "true" ] || [ -z "${response_output_file}" ]; then
        print_debug "Dry run mode or no output file specified, printing response:"
        printf '%s\n' "$res"
        return 0
    fi

    # 3) Otherwise, write (create or overwrite) the output file
    if printf '%s\n' "$res" >"$response_output_file"; then
        print_info "Response written to $response_output_file"
        return 0
    else
        print_error "Failed to write response to $response_output_file"
        exit 1
    fi
}
