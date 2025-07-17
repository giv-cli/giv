Here’s a polished version of `parse_args()` that you can drop into `giv.sh`. It handles:

* Uppercase `GIV_`-prefixed env vars
* Merges configuration sources in the order: **CLI args → --config-file → .giv/.givrc → env vars**
* Supports `togiv` config options: `PROJECT_TITLE`, `PROJECT_DESCRIPTION`, `PROJECT_URL`, `TEMPLATE_DIR`, `TEMPERATURE`, `MODEL`
* Initializes `.giv` on first run

Feel free to copy-paste; I’ve added explanatory comments throughout.

```bash
# --------------------------------------------------
# parse_args: handle CLI args, config overrides, env vars
# --------------------------------------------------
parse_args() {
  # Default config file in .giv
  GIV_RC_FILE="${GIV_RC_FILE:-.giv/.givrc}"

  # Defaults from environment
  GIV_PROJECT_TITLE="${GIV_PROJECT_TITLE:-}"
  GIV_PROJECT_DESCRIPTION="${GIV_PROJECT_DESCRIPTION:-}"
  GIV_PROJECT_URL="${GIV_PROJECT_URL:-}"
  GIV_TEMPLATE_DIR="${GIV_TEMPLATE_DIR:-.giv/templates}"
  GIV_TEMPERATURE="${GIV_TEMPERATURE:-}"
  GIV_MODEL="${GIV_MODEL:-}"

  # CLI flags (initialized empty)
  override_project_title=""
  override_project_description=""
  override_project_url=""
  override_template_dir=""
  override_temperature=""
  override_model=""
  override_config_file=""

  # Parse CLI options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project-title) override_project_title="$2"; shift 2 ;;
      --project-description) override_project_description="$2"; shift 2 ;;
      --project-url) override_project_url="$2"; shift 2 ;;
      --template-dir) override_template_dir="$2"; shift 2 ;;
      --temperature) override_temperature="$2"; shift 2 ;;
      --model) override_model="$2"; shift 2 ;;
      --config-file) override_config_file="$2"; shift 2 ;;
      init)
        cmd_init=1 ; shift ;;
      *) POSITIONAL+=("$1"); shift ;;
    esac
  done
  set -- "${POSITIONAL[@]}"

  # Allow 'init' subcommand to bypass missing .giv
  if [[ "${cmd_init:-}" = "1" ]]; then
    GIV_CONFIG_SKIP=1
  else
    ensure_giv_dir
  fi

  # Load config from --config-file if explicit, else from GIV_RC_FILE
  if [[ -n "$override_config_file" ]]; then
    cfg="$override_config_file"
  else
    cfg="$GIV_RC_FILE"
  fi

  if [[ -r "$cfg" ]]; then
    # shell-style key=value
    source "$cfg"
  fi

  # Now apply precedence: CLI args > config file > env vars
  [[ -n "$override_project_title" ]] && GIV_PROJECT_TITLE="$override_project_title"
  [[ -n "$override_project_description" ]] && GIV_PROJECT_DESCRIPTION="$override_project_description"
  [[ -n "$override_project_url" ]] && GIV_PROJECT_URL="$override_project_url"
  [[ -n "$override_template_dir" ]] && GIV_TEMPLATE_DIR="$override_template_dir"
  [[ -n "$override_temperature" ]] && GIV_TEMPERATURE="$override_temperature"
  [[ -n "$override_model" ]] && GIV_MODEL="$override_model"

  # Export final vars
  export GIV_PROJECT_TITLE GIV_PROJECT_DESCRIPTION GIV_PROJECT_URL
  export GIV_TEMPLATE_DIR GIV_TEMPERATURE GIV_MODEL

  # Validate mandatory fields
  if [[ -z "$GIV_MODEL" ]]; then
    echo "Error: model must be defined (via ENV, .giv/.givrc, or --model)"
    exit 1
  fi
}
```

### Utility: `.giv` initialization

```bash
ensure_giv_dir() {
  if [[ ! -d ".giv" || ! -f ".giv/.givrc" ]]; then
    mkdir -p .giv/{templates,.tmp,.cache}
    cat > .giv/.givrc <<EOF
# Sample GIV config — edit as needed
GIV_PROJECT_TITLE=""
GIV_PROJECT_DESCRIPTION=""
GIV_PROJECT_URL=""
GIV_TEMPLATE_DIR=".giv/templates"
GIV_TEMPERATURE="0.7"
GIV_MODEL="gpt-4"
EOF
    echo "Initialized .giv/ with default template and config structure."
  fi
}
```

---

### 📘 How it works:

1. **Loads `.env`-style env vars** (e.g. `GIV_MODEL`) early.
2. **Parses CLI flags**, storing only overrides.
3. **Initializes `.giv/` folder** automatically (or via `giv init`).
4. **Loads `.giv/.givrc` or alternate config file** if specified with `--config-file`.
5. **Applies overrides** in the correct priority: CLI > config file > env.
6. **Ensures essential vars** (e.g. `GIV_MODEL`) are defined at end.

---

### ✅ Usage examples

```bash
# Automatic init and run
./giv.sh generate

# Use custom model & temperature
./giv.sh --model gpt-4 --temperature 0.3 generate ...

# Override config file
./giv.sh --config-file custom.cfg generate

# Manual initialization
./giv.sh init
```

This implementation respects your requested config hierarchy and stores everything in `.giv/` cleanly. Let me know if you’d like support for interactive prompting, binder CI overrides, or other flags!
