#!/bin/sh
# POSIX-sh helpers for inserting/updating Markdown sections

# strip_markdown: remove common Markdown formatting from input text
#
# Reads from stdin and writes stripped text to stdout.
#
# Usage:
#   echo "$markdown" | strip_markdown
#
# strip_markdown: remove common Markdown formatting
# Reads from stdin, writes plain text to stdout
strip_markdown() {
  sed -e '/^[[:blank:]]*```.*$/d' \
    -e 's/!\[[^]]*\](\([^)]*\))//g' \
    -e 's/\[\([^]]*\)\](\([^)]*\))/\1/g' \
    -e 's/`//g' \
    -e 's/\*\*\([^*][^*]*\)\*\*/\1/g' \
    -e 's/\*\([^*][^*]*\)\*/\1/g' \
    -e 's/^[[:blank:]]*#\+[[:blank:]]*//g' \
    -e 's/^[[:blank:]]*>[[:blank:]]*//g' \
    -e 's/^[[:blank:]]*[-+*][[:blank:]]*//g' \
    -e 's/^[[:blank:]]*[0-9]\+\.[[:blank:]]*//g'
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

# manage_section <title> <file> <new_content_file> <mode> <section_id> [<header_id>]
#   mode: append|prepend|update
#   header_id: literal "#" string (e.g. "##" or "###"), defaults to "##"
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
  tmp=$(portable_mktemp "markdown-temp.XXXXXXX.md") || return 1

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

  tmp=$(portable_mktemp "append-link-temp.XXXXXXXX.md") || {
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
  elif command -v port >/dev/null 2>&1; then
    sudo port install glow && return 0
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm glow && return 0
  elif command -v xbps-install >/dev/null 2>&1; then
    sudo xbps-install -Sy glow && return 0
  elif command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p glow --run glow && return 0
  elif command -v pkg >/dev/null 2>&1 && uname -s | grep -qi freebsd; then
    sudo pkg install -y glow && return 0
  elif command -v eopkg >/dev/null 2>&1; then
    sudo eopkg install glow && return 0
  elif command -v snap >/dev/null 2>&1; then
    sudo snap install glow && return 0
  elif command -v choco >/dev/null 2>&1; then
    choco install glow -y && return 0
  elif command -v scoop >/dev/null 2>&1; then
    scoop install glow && return 0
  elif command -v winget >/dev/null 2>&1; then
    winget install --id=charmbracelet.glow -e && return 0
  fi
  return 1
}

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

# print_md: print Markdown content to stdout
# Usage: echo "# Markdown" | print_md
print_md() {

  glow() { return 1; }
  #if is_glow_installed >/dev/null 2>&1; then
  if [ "$(command -v glow)" ]; then
    glow -n -w 0
  else
    strip_markdown
  fi
}
