#!/bin/bash
# Template processing library

# Process template file with variable substitution
process_template() {
    local template_file="$1"
    local output_file="$2"
    local temp_file
    
    if [[ ! -f "$template_file" ]]; then
        echo "ERROR: Template file not found: $template_file" >&2
        return 1
    fi
    
    temp_file=$(mktemp)
    
    # Copy template to temp file
    cp "$template_file" "$temp_file"
    
    # Get list of all template variables in the file
    local variables
    variables=$(grep -o '{{[^}]*}}' "$template_file" | sed 's/[{}]//g' | sort -u)
    
    # Process each template variable
    while IFS= read -r var_name; do
        [[ -z "$var_name" ]] && continue
        
        local var_value="${!var_name:-}"
        
        if [[ -z "$var_value" ]]; then
            echo "WARNING: Template variable $var_name is not set" >&2
            var_value="MISSING_${var_name}"
        fi
        
        # Escape special characters for sed
        var_value_escaped=$(printf '%s\n' "$var_value" | sed 's/[[\.*^$()+?{|]/\\&/g; s/\//\\\//g')
        
        # Replace all occurrences of the template variable
        sed -i "s/{{${var_name}}}/${var_value_escaped}/g" "$temp_file"
        
    done <<< "$variables"
    
    # Move processed template to output
    mv "$temp_file" "$output_file"
}

# Validate that all template variables were substituted
validate_template_processed() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found for validation: $file" >&2
        return 1
    fi
    
    if grep -q '{{.*}}' "$file"; then
        echo "ERROR: Unprocessed template variables found in $file:" >&2
        grep -o '{{[^}]*}}' "$file" | sort -u >&2
        return 1
    fi
    
    return 0
}

# Set template variables from configuration
set_template_vars() {
    # Source the config if not already loaded
    if [[ -z "${GIV_PACKAGE_NAME:-}" ]]; then
        local script_dir
        script_dir="$(dirname "${BASH_SOURCE[0]}")"
        # shellcheck source=../config.sh
        . "$script_dir/../config.sh"
    fi
    
    # Export commonly used template variables
    export VERSION="${1:-$(get_version)}"
    export PACKAGE_NAME="$GIV_PACKAGE_NAME"
    export DESCRIPTION="$GIV_DESCRIPTION"
    export MAINTAINER="$GIV_MAINTAINER"
    export LICENSE="$GIV_LICENSE"
    export REPOSITORY="$GIV_REPOSITORY"
    
    # For backward compatibility with existing templates
    export GIV_VERSION="$VERSION"
}

# Process template with automatic variable setting
process_template_auto() {
    local template_file="$1"
    local output_file="$2"
    local version="${3:-}"
    
    # Set template variables
    set_template_vars "$version"
    
    # Process the template
    process_template "$template_file" "$output_file"
    
    # Validate processing was successful
    validate_template_processed "$output_file"
}

# Generate file lists for templates (used by PyPI setup.py)
generate_file_lists() {
    local build_temp="$1"
    
    if [[ ! -d "$build_temp/package" ]]; then
        echo "ERROR: Package directory not found: $build_temp/package" >&2
        return 1
    fi
    
    # Generate file lists for template substitution
    export SH_FILES
    SH_FILES=$(find "$build_temp/package/src" -type f -name '*.sh' -print0 | \
        xargs -0 -I{} bash -c 'printf "\"src/%s\", " "$(basename "{}")"' | \
        sed 's/, $//')
    
    export TEMPLATE_FILES  
    TEMPLATE_FILES=$(find "$build_temp/package/templates" -type f -print0 | \
        xargs -0 -I{} bash -c 'printf "\"templates/%s\", " "$(basename "{}")"' | \
        sed 's/, $//')
    
    export DOCS_FILES
    DOCS_FILES=$(find "$build_temp/package/docs" -type f -print0 | \
        xargs -0 -I{} bash -c 'printf "\"docs/%s\", " "$(basename "{}")"' | \
        sed 's/, $//')
}

# Test function to validate template processing
test_template_processing() {
    local test_template="/tmp/test_template.txt"
    local test_output="/tmp/test_output.txt"
    
    # Create test template
    cat > "$test_template" << 'EOF'
Package: {{PACKAGE_NAME}}
Version: {{VERSION}}
Description: {{DESCRIPTION}}
EOF
    
    # Set test variables
    export PACKAGE_NAME="test-package"
    export VERSION="1.0.0"
    export DESCRIPTION="Test description"
    
    # Process template
    if process_template "$test_template" "$test_output"; then
        echo "Template processing test: PASSED"
        cat "$test_output"
    else
        echo "Template processing test: FAILED"
        return 1
    fi
    
    # Validate processing
    if validate_template_processed "$test_output"; then
        echo "Template validation test: PASSED"
    else
        echo "Template validation test: FAILED"
        return 1
    fi
    
    # Cleanup
    rm -f "$test_template" "$test_output"
}

# Run test if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Testing template processing..."
    test_template_processing
fi