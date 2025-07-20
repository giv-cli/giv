Lets implement this feature:

Extendable Project-Level Metadata Architecture for giv

Objective

Augment giv so that rich project metadata is collected once per invocation (early in the run pipeline) from:

1. Known project types via provider scripts (e.g. Node, Python, Rust, Go).

2. User configuration (override or supplement autodetected values) via .giv/config.

3. Custom project type definitions allowing users to specify metadata or files to parse.

The collected metadata—cached under .giv/cache—will be exposed to all prompt-building logic, enabling templates (announcements, release notes, README generation, etc.) to incorporate:

title

url (homepage or documentation)

description

repository\_url

latest\_version

language

license

author / authors

dependencies (list)

dev\_dependencies (list)

scripts (build, test, etc.)

vcs info (default branch, commit SHA, tag count)

This POSIX-compliant design ensures portability across /bin/sh implementations.

---

High-Level Architecture Changes

1. Metadata Phase: Add a metadata\_init call immediately after argument parsing in giv.sh.

2. Provider Registry: Under project/providers/, each provider\_<id>.sh implements detection and collection functions in POSIX shell.

3. Orchestrator: New project/metadata.sh sources providers, detects, prioritizes, collects, merges, caches, and exports metadata.

4. Prompt Integration: Extend llm.sh’s build\_prompt to inject metadata from cache and support \${{meta.<key>}} tokens.

5. Configuration: Add keys in .giv/config:

GIV\_PROJECT\_TYPE to force a provider or set to "auto" for autodetection

GIV\_PROJECT\_METADATA\_FILE for external .env file

---

Provider Interface (POSIX Shell)

Each provider\_<id>.sh must define:

# Detect presence (0 = yes, >0 = no)

provider\_<id>\_detect() {

# e.g. \[ -f "package.json" \]

return 1
}

# Collect metadata: output KEY\tVALUE per line

provider\_<id>\_collect() {

# echo "title\tMy Project"

}

---

Directory Layout

project/
metadata.sh # orchestrator
providers/
provider\_node\_pkg.sh
provider\_python\_pep621.sh
provider\_generic\_git.sh
.giv/
cache/
project\_metadata.env
config # overrides

---

Simplified Orchestration Flow (POSIX Steps)

1. Determine Provider:

if [ "$GIV\_PROJECT\_TYPE" = "custom" ]; then
[ -f "$GIV\_HOME/project\_provider.sh" ] && . "$GIV\_HOME/project\_provider.sh"
elif [ "$GIV\_PROJECT\_TYPE" = "auto" ]; then
for f in "$GIV\_LIB\_DIR/project/providers"/*.sh; do
. "$f"
provider\_detect=$(set | awk -F'=' '/^provider\_.\*\_detect=/ { sub("()","",\$1); print \$1 }')
for fn in \$provider\_detect; do
\$fn && DETECTED\_PROVIDER="\$fn" && break
done
[ -n "$DETECTED_PROVIDER" ] && break
done
else
. "$GIV\_LIB\_DIR/project/providers/provider\_${GIV\_PROJECT\_TYPE}.sh"
fi

2. Collect Metadata:

if [ -n "$DETECTED\_PROVIDER" ]; then
coll=${DETECTED\_PROVIDER%_detect}\_collect
$coll | while IFS="\t" read -r key val; do
printf '%s=%s\n' "$key" "${val//"/\\"}" >> "$GIV\_CACHE\_DIR/project\_metadata.env"
done
fi

3. Apply Overrides:

[ -f "$GIV\_HOME/project\_metadata.env" ] && . "$GIV\_HOME/project\_metadata.env"

4. Export:

# shell export

set -a
. "$GIV\_CACHE\_DIR/project\_metadata.env"
set +a

---

Cache Format

project\_metadata.env: simple KEY=value lines

Example project\_metadata.env:

title=My Project
author=Jane Doe
latest\_version=1.2.3
repository\_url=https://github.com/org/repo.git

---

Prompt Token Usage

Templates can use tokens like:

Project: [title] (v[latest_version])
Home: [url]
Repo: [repository_url]
Desc: [description]
License: [license]

---

Configuration (.giv/config)

GIV\_PROJECT\_TYPE=auto
GIV\_PROJECT\_METADATA\_FILE=metadata.env
GIV\_PROJECT\_METADATA\_EXTRA<<'EOF'
owner.team=platform
tier=gold
EOF

---

Testing & Validation Checklist

\[ \] Providers detect correctly in mixed-type repos

\[ \] Keys include title, url, description, repository\_url, latest\_version

\[ \] Overrides apply with correct precedence

\[ \] Cache files (.env) generate and load properly

\[ \] Prompt tokens replace as expected

\[ \] POSIX shell lint (shellcheck -s sh)

\[ \] --refresh-metadata flag forces reload

---

Implementation Checklist

\[ \] Create project/metadata.sh orchestrator (POSIX)

\[ \] Build built-in providers: node\_pkg, python\_pep621, generic\_git

\[ \] Source custom providers from $GIV\_HOME/project\_provider.sh

\[ \] Write metadata to .giv/cache/project\_metadata.env

\[ \] Update giv.sh to call metadata\_init

\[ \] Extend llm.sh build\_prompt for \${{meta.\*}} tokens

\[ \] Add config parsing in args.sh or config.sh

\[ \] Add --refresh-metadata support

\[ \] Write Bats tests for detection, caching, overrides

\[ \] Document usage in README
