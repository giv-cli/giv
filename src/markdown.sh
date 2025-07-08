#!/bin/sh
# POSIX-sh helpers for inserting/updating Markdown sections

# Collapse multiple blank lines to one, ensure exactly one blank at EOF
normalize_blank_lines() {
  in="$1"
  awk '
    NF { print; prev=1 }
    !NF { if (prev) print; prev=0 }
    END { if (prev) print "" }
  ' "$in" >"$in".norm && mv "$in".norm "$in"
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

