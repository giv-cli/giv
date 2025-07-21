#!/bin/sh
# POSIX-sh helpers for inserting/updating Markdown sections


# Remove top-level markdown header (e.g. "# Title")
remove_top_level_header() {
    sed '1{/^#[[:space:]]/d;}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"      
}

# Remove triple backtick code fences from the first and last line (if present)
strip_code_fences() {

    # Remove code fences on a single line (e.g. ```Code```)
    sed 's/^```\(.*\)```$/\1/' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    
    # Remove code fence if first line is only ```
    first_line=$(head -n 1 "$1")
    if [ "$first_line" = '```' ]; then
        tail -n +2 "$1" > "$1.tmp" && mv "$1.tmp" "$1"
    fi
    # Remove code fence if last line is only ```
    last_line=$(tail -n 1 "$1")
    if [ "$last_line" = '```' ]; then
        line_count=$(wc -l < "$1")
        if [ "$line_count" -gt 1 ]; then
            head -n $((line_count - 1)) "$1" > "$1.tmp" && mv "$1.tmp" "$1"
        else
            : > "$1"
        fi
    fi
    
    
}

# Ensure the file ends with exactly one newline (add only if missing)
enforce_final_newline() {
    [ -f "$1" ] || return 0
    
        # If the last line is not empty, add a newline
    if [ ! "$(tail -n 2 "$1")" = "\n" ]; then        
        cat "$1" > "$1.tmp"
        printf '\n' >> "$1.tmp"
        mv "$1.tmp" "$1"
    fi
}

# Apply all post-processing steps to a file
post_process_document() {
    file="$1"
    remove_top_level_header "$file"
    strip_code_fences "$file"
    normalize_blank_lines "$file"
}

strip_markdown() {
    # Reads from stdin and writes stripped text to stdout.
    
    sed -e '/^[[:blank:]]*```.*$/d' \
    -e 's/!\[[^]]*\](\([^)]*\))//g' \
    -e 's/\[\([^]]*\)\](\([^)]*\))/\1/g' \
    -e 's/`//g' \
    -e 's/\*\*\([^*][^*]*\)\*\*/\1/g' \
    -e 's/\*\([^*][^*]*\)\*/\1/g' \
    -e 's/^[[:blank:]]*#[[:blank:]]*//g' \
    -e 's/^[[:blank:]]*>[[:blank:]]*//g'
}

# Collapse multiple blank lines to one, ensure exactly one blank at EOF
normalize_blank_lines() {
    in="$1"
    awk '
    NF { print; prev=1 }
    !NF { if (prev) print; prev=0 }
    END { if (prev) print "" }
    ' "$in" >"$in".norm && mv "$in".norm "$in"
}

# extract_section <section_name> <markdown_file> [<header_id>]
#
# Prints the matching section (including its heading) and its content
# up to—but not including—the next heading of the same or higher level.
#
#   <section_name>  The literal text of the heading (e.g. "1.0.0" or "Unreleased")
#   <markdown_file> Path to the file to search
#   <header_id>     Heading marker (e.g. "##" or "###"); defaults to "##"
#
# Returns 0 always; prints nothing if file or section is missing.
extract_section() {
    section=$1
    file=$2
    header=${3:-"##"}
    
    # nothing to do if file absent
    [ ! -f "$file" ] && return 0
    
    # escape section name for regex
    esc=$(printf '%s' "$section" | sed 's/[][\\/.*^$]/\\&/g')
    
    # build pattern to find the heading line
    pat="^${header}[[:space:]]*\\[?${esc}\\]?"
    
    # locate the first matching heading line number
    start=$(grep -nE "$pat" "$file" 2>/dev/null | head -n1 | cut -d: -f1)
    [ -z "$start" ] && return 0
    
    # count how many "#" in header to get its level
    HL=${#header}
    
    # build a regex matching any heading of level ≤ HL
    lvl_pat="^#{1,${HL}}[[:space:]]"
    
    # find the next heading (same or higher level) after start
    offset=$(tail -n +"$((start + 1))" "$file" |
        grep -nE "$lvl_pat" |
        head -n1 |
    cut -d: -f1)
    
    if [ -n "$offset" ]; then
        end=$((start + offset - 1))
    else
        # no further heading: go to EOF
        end=$(wc -l <"$file")
    fi
    
    # print from the header line through end
    sed -n "${start},${end}p" "$file"
}

# manage_section - Manages sections within a markdown file.
#
# This function allows for appending, prepending, or updating a section within a markdown file.
# It takes care of handling the header and content insertion while preserving the original structure.
#
# Parameters:
#   title (string)       : The title to be used in the markdown file.
#   file (string)        : Path to the existing markdown file.
#   newf (string)        : Path to the new content file to be inserted.
#   mode (string)        : Mode of operation: 'append', 'prepend', or 'update'.
#   section (string)     : The section header to manage within the markdown file.
#   header (string, opt) : The header level for the section. Defaults to "##".
#
# Returns:
#   Path to a temporary file containing the modified markdown content.
manage_section() {
    title=$1
    file=$2
    newf=$3
    mode=$4
    section=$5
    header=${6:-"##"}
    
    # read original (or empty if missing)
    [ -f "$file" ] && orig="$file" || orig="/dev/null"
    
    # pick tmp
    tmp=$(portable_mktemp "markdown-temp.XXXXXXX") || return 1
    
    # if mode=update but no existing header, fall back to prepend
    if [ "$mode" = update ] && ! grep -qE "^${header}[[:space:]]*${section}([[:space:]]|\$)" "$orig"; then
        mode=prepend
    fi
    
    case "$mode" in
        append)
            {
                cat "$orig"
                printf "\n%s %s\n\n" "$header" "$section"
                cat "$newf"
            } >"$tmp"
        ;;
        
        prepend)
            awk -v title="$title" \
            -v header="$header" \
            -v section="$section" \
            -v cf="$newf" '
        BEGIN {
          HL = length(header)
          # read the replacement text
          while ((getline L < cf) > 0) newc = newc L "\n"
          close(cf)
        }
        { A[NR] = $0 }
        END {
          # --- completely empty file: just title + section + content
          if (NR == 0) {
            print title
            print ""                       # blank line
            print header " " section
            print ""                       # blank line before content
            printf "%s", newc
            exit
          }

          # --- find the title line
          for (i = 1; i <= NR; i++)
            if (A[i] == title) { t = i; break }

          # --- no explicit title: insert at top
          if (!t) {
            print title
            print ""
            print header " " section
            print ""
            printf "%s", newc
            for (i = 1; i <= NR; i++) print A[i]
            exit
          }

          # --- otherwise, find first same‐level header after the title
          for (i = t+1; i <= NR; i++) {
            if (substr(A[i],1,HL) == header && A[i] ~ "^" header "[[:space:]]")
              { ins = i; break }
          }
          if (ins == "") ins = t + 1

          # output everything up to the insertion point
          for (i = 1; i < ins; i++) print A[i]
          if (A[ins-1] != "") print ""    # ensure a blank line before new section
          print header " " section
          print ""                         # blank line before content
          printf "%s", newc
          if (newc !~ /\n$/) print ""      # ensure final newline if missing
          for (i = ins; i <= NR; i++) print A[i]
            }' "$orig" >"$tmp"
        ;;
        
        update)
            awk -v header="$header" \
            -v section="$section" \
            -v cf="$newf" '
      BEGIN {
        HL = length(header)
        # slurp new content
        while ((getline L < cf) > 0) newc = newc L "\n"
        close(cf)
        insec=0; done=0
      }
      {
        # start of target section?
        if (!done && !insec && $0 ~ "^" header "[[:space:]]*" section "([[:space:]]|$)") {
          print; print ""; printf "%s", newc
          insec=1; done=1; next
        }
        # skip old section content
        if (insec) {
          if ($0 ~ "^#+") {
            match($0, /#+/); lvl = RLENGTH
            if (lvl <= HL) {
              insec=0
              print
            }
          }
          next
        }
        print
      }
            ' "$orig" >"$tmp"
        ;;
        
        *)
            printf 'Invalid mode provided: %s\n' "$mode"
            rm -f "$tmp"
            return 1
        ;;
    esac
    
    # normalize and return tmp path
    normalize_blank_lines "$tmp"
    printf '%s\n' "$tmp"
}

# append_link <file> <title> <url>
#  - if URL is empty: prints a debug msg, returns 0, no change
#  - if the exact [title](url) already exists: prints debug, returns 0
#  - otherwise: trims trailing blank lines, ensures one blank above + one below,
#    appends the link, moves temp → original, prints debug, returns 0
append_link() {
    file=$1
    title=$2
    url=$3
    prefix="DEBUG: append_link:"
    if [ -z "$url" ]; then
        printf '%s URL is empty, skipping\n' "$prefix" >&2
        return 0
    fi
    
    link="[$title]($url)"
    
    if [ -f "$file" ] && grep -Fq "$link" "$file"; then
        printf '%s Link already exists: %s\n' "$prefix" "$link" >&2
        return 0
    fi
    
    tmp=$(portable_mktemp "append-link-temp.XXXXXXXX") || {
        printf '%s Failed to create temp file\n' "$prefix" >&2
        return 0
    }
    
    # if the file doesn't exist, read from /dev/null and note creation
    input="$file"
    if [ ! -f "$file" ]; then
        input="/dev/null"
        printf '%s File %s does not exist; creating\n' "$prefix" "$file" >&2
    fi
    
    awk -v link="$link" '
    { lines[n++] = $0 }
    END {
      # remove any trailing blank lines
      end = n
      while (end > 0 && lines[end-1] == "") end--

      # print everything up to that point
      for (i = 0; i < end; i++) print lines[i]

      # if there was existing content, ensure exactly one blank line above
      if (end > 0) print ""

      # append the link, then a blank line
      print link
      print ""
    }
    ' "$input" >"$tmp"
    
    mv "$tmp" "$file"
    printf '%s Appended link: %s to %s\n' "$prefix" "$link" "$file" >&2
    return 0
}

is_glow_installed() {
    command -v glow >/dev/null 2>&1
}

install_pkg() {
    echo "Checking package managers..."
    if command -v brew >/dev/null 2>&1; then
        brew install glow && return 0
        elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm glow && return 0
        elif command -v snap >/dev/null 2>&1; then
        sudo snap install glow && return 0
        elif command -v scoop >/dev/null 2>&1; then
        scoop install glow && return 0
    fi
    return 1
}

# This function installs the 'glow' binary from GitHub releases.
#
# It performs the following steps:
# 1. Determines the operating system and architecture.
# 2. Fetches the latest release tag from the charmbracelet/glow repository.
# 3. Downloads the appropriate tarball and checksum file for the detected OS and architecture.
# 4. Verifies the integrity of the downloaded file using SHA-256 checksums.
# 5. Extracts the binary, makes it executable, and moves it to /usr/local/bin.
#
# Parameters:
#   None
#
# Returns:
#   0 on success, non-zero on failure
install_from_github() {
    echo "Installing glow binary from GitHub releases…"
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "$arch" in
        x86_64 | amd64) arch="x86_64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *)
            echo "Unsupported arch: $arch"
            exit 1
        ;;
    esac
    
    tag=$(curl -fsSL https://api.github.com/repos/charmbracelet/glow/releases/latest |
    grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    file="glow_${tag#v}_${os}_${arch}.tar.gz"
    
    tmpdir=$(mktemp -d)
    curl -fsSL "https://github.com/charmbracelet/glow/releases/download/$tag/$file" -o "$tmpdir/glow.tar.gz"
    curl -fsSL "https://github.com/charmbracelet/glow/releases/download/$tag/checksums.txt" -o "$tmpdir/checksums.txt"
    
    cd "$tmpdir" || exit 1
    sha256sum -c checksums.txt --ignore-missing --quiet || {
        echo "Checksum verification failed"
        exit 1
    }
    
    tar -xzf glow.tar.gz
    chmod +x glow
    
    bindir="/usr/local/bin"
    if [ -w "$bindir" ]; then
        mv glow "$bindir"
    else
        sudo mv glow "$bindir"
    fi
    
    cd - || exit 1
    rm -rf "$tmpdir"
    
    echo "glow installed to $bindir"
}


# ensure_glow - Ensures that the 'glow' command-line tool is installed.
#
# This function checks if 'glow' is already installed on the system. If it is not,
# it attempts to install it using a package manager first, and if that fails, it
# installs it from GitHub. It then verifies whether the installation was successful.
#
# Exits with status 1 if the installation fails.
ensure_glow() {
    if is_installed; then
        echo "✔ glow already installed: $(command -v glow)"
        return
    fi
    
    echo "✗ glow not found. Installing…"
    if install_pkg; then
        echo "Installed via package manager."
    else
        install_from_github
    fi
    
    if ! is_installed; then
        echo "Installation failed. See https://github.com/charmbracelet/glow#installation"
        exit 1
    fi
}

# This function prints a markdown file using the 'glow' command.
#
# Usage: print_md_file <file>
#
# Arguments:
#   <file> - The path to the markdown file to be printed.
#
# Returns:
#   0 on success, 1 if no argument is provided or the file does not exist.
print_md_file() {
    ensure_glow
    if [ -z "$1" ]; then
        echo "Usage: view_md <file>"
        return 1
    fi
    
    if [ ! -f "$1" ]; then
        echo "File not found: $1"
        return 1
    fi
    
    glow "$1"
}

# Added a new helper function to handle Markdown output.

print_md() {
    if command -v glow >/dev/null 2>&1; then
        glow -   # read from stdin
    else
        cat -
    fi
}
