#! /bin/sh

# Update the script to a specific release version (or latest if not specified)

version="${1:-latest}"
available_releases="$(curl -s https://api.github.com/repos/giv-cli/giv/releases \
    | awk -F'"' '/"tag_name":/ {print $4}')"
    
if [ "${version}" = "latest" ]; then
    latest_version=$(echo "${available_releases}" | head -n 1)
    printf 'Updating giv to version %s...\n' "${latest_version}"
    curl -fsSL https://raw.githubusercontent.com/giv-cli/giv/main/install.sh | sh -- --version "${latest_version}"
else
    printf 'Updating giv to version %s...\n' "${version}"
    curl -fsSL "https://raw.githubusercontent.com/giv-cli/giv/main/install.sh" | sh -- --version "${version}"
fi
printf 'Update complete.\n'