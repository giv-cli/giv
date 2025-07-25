#!/usr/bin/env bash
set -euo pipefail

report() { printf "\n== %s ==\n" "$*"; }

# Helper: check PATH for giv
expect_giv_in_path() {
    if ! command -v giv >/dev/null 2>&1; then
        echo "FAIL: giv not found in PATH after install."
        exit 1
    fi
    echo "PASS: giv found in PATH."
}

expect_giv_not_in_path() {
    if command -v giv >/dev/null 2>&1; then
        echo "FAIL: giv still found in PATH after uninstall."
        exit 1
    fi
    echo "PASS: giv not in PATH after uninstall."
}

# File checkers for each package manager
deb_rpm_check() {
    expect_file_exists /usr/local/bin/giv
    expect_file_exists /usr/local/lib/giv/helpers.sh
    expect_file_exists /usr/local/share/giv/templates/summary_prompt.md
}

pip_check() {
    # 1) Find venv base
    VENV_BIN="$(dirname "$(command -v giv)")"
    VENV_BASE="$(dirname "$VENV_BIN")"

    # 2) The CLI entrypoint
    expect_file_exists "$VENV_BIN/giv"

    # 3) Our two .sh helpers
    expect_file_exists "$VENV_BASE/src/markdown.sh"
    expect_file_exists "$VENV_BASE/src/helpers.sh"

    # 4) At least one template under <venv>/templates
    if [ ! -d "$VENV_BASE/templates" ]; then
        echo "FAIL: template directory not found: $VENV_BASE/templates"
        exit 1
    fi
    found=0
    for f in "$VENV_BASE/templates"/*.md; do
        [ -e "$f" ] && {
            found=1
            break
        }
    done
    if [ "$found" -ne 1 ]; then
        echo "FAIL: no .md files in $VENV_BASE/templates"
        exit 1
    fi

    # 5) At least one doc under <venv>/docs (allow nested)
    if [ ! -d "$VENV_BASE/docs" ]; then
        echo "FAIL: docs directory not found: $VENV_BASE/docs"
        exit 1
    fi
    found=0
    # top-level and one level deep
    for f in "$VENV_BASE/docs"/*.md "$VENV_BASE/docs"/*/*.md; do
        [ -e "$f" ] && {
            found=1
            break
        }
    done
    if [ "$found" -ne 1 ]; then
        echo "FAIL: no .md files in $VENV_BASE/docs or its subdirectories"
        exit 1
    fi

    echo "PASS: PyPI files found."
}

npm_check() {
    # ─── detect package manager and derive paths ─────────────────────────────────
    if command -v npm >/dev/null 2>&1; then
        # npm exists: use its config
        NPM_PREFIX=$(npm config get prefix)
        NPM_BIN="$NPM_PREFIX/bin"
        NPM_ROOT="$NPM_PREFIX/lib/node_modules"
    elif command -v yarn >/dev/null 2>&1; then
        # Yarn (classic) has its own globals
        NPM_BIN=$(yarn global bin)
        # `yarn global dir` gives the root of the yarn global installation
        NPM_ROOT="$(yarn global dir)/node_modules"
    else
        echo "ERROR: neither npm nor yarn found on PATH" >&2
        exit 1
    fi

    # ─── sanity-check that the dirs actually exist ─────────────────────────────────
    if [ ! -d "$NPM_BIN" ]; then
        echo "WARN: expected bin dir not found: $NPM_BIN" >&2
    fi
    if [ ! -d "$NPM_ROOT" ]; then
        echo "WARN: expected root dir not found: $NPM_ROOT" >&2
    fi
    expect_file_exists "$NPM_BIN/giv"
    expect_file_exists "$NPM_ROOT/giv/src/helpers.sh"
    expect_file_exists "$NPM_ROOT/giv/templates/summary_prompt.md"
}

snap_check() {
    expect_file_exists /snap/bin/giv
    # Try to resolve $SNAP for the test context
    SNAPDIR="$(readlink -f /snap/giv/current)"
    expect_file_exists "$SNAPDIR/lib/giv/helpers.sh"
    expect_file_exists "$SNAPDIR/share/giv/templates/summary_prompt.md"
}

expect_file_exists() {
    for file in "$@"; do
        if [ ! -e "$file" ]; then
            echo "FAIL: Expected file $file not found after install."
            exit 1
        fi
    done
    echo "PASS: All expected files found."
}

# --------- Run for each package manager ---------

VERSION=$(sed -n 's/^__VERSION="\([^"]*\)"/\1/p' src/giv.sh)

mkdir -p .tmp/validate-installs
cd .tmp/validate-installs

report "Testing deb install (APT)"
sudo apt-get update
sudo apt-get install -y ../../dist/*/deb/*.deb
expect_giv_in_path
deb_rpm_check
sudo apt-get remove -y giv
expect_giv_not_in_path

# TODO: Will need RPM distro docker image to test
# report "Testing rpm install (YUM/DNF)"
# sudo dnf install -y ../../dist/*/rpm/*.rpm || sudo yum install -y ../../dist/*/rpm/*.rpm
# expect_giv_in_path
# deb_rpm_check
# sudo dnf remove -y giv || sudo yum remove -y giv
# expect_giv_not_in_path

report "Testing PyPI install (pip)"
python3 -m venv pipenv
. pipenv/bin/activate
pip install ../../dist/*/pypi/
expect_giv_in_path
pip_check
pip uninstall -y giv
expect_giv_not_in_path
deactivate
rm -rf ../../dist/*/pypi/build
rm -rf ../../dist/*/pypi/src/giv.*

report "Testing npm install (npm)"
npm install -g ../../dist/*/npm/
expect_giv_in_path
npm_check
npm uninstall -g giv
expect_giv_not_in_path

# TODO: cannot test in docker, need to rethink this
# report "Testing snap install"
# sudo systemctl start snapd || sudo service snapd start || true
# sudo snap install core || true
# sudo snap install --dangerous ../../dist/*/snap/*.snap
# expect_giv_in_path
# snap_check
# sudo snap remove giv
# expect_giv_not_in_path

report "Testing brew install (Homebrew)"

# locate the local formula
mv "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb" "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb.bak"
mv "$(pwd)/../../dist/${VERSION}/homebrew/giv.local.rb" "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb"
FORMULA="$(pwd)/../../dist/${VERSION}/homebrew/giv.rb"
[ -f "$FORMULA" ] || {
    echo "FAIL: Homebrew formula not found at $FORMULA"
    exit 1
}

# install from that tarball as the linuxbrew user
su - linuxbrew -c "
    export HOMEBREW_NO_INSTALL_CLEANUP=1
    export HOMEBREW_NO_ENV_HINTS=1
    export HOMEBREW_NO_AUTO_UPDATE=1
    /home/linuxbrew/.linuxbrew/bin/brew install --build-from-source '$FORMULA'
  "

expect_giv_in_path

# uninstall and confirm removal
su - linuxbrew -c '/home/linuxbrew/.linuxbrew/bin/brew uninstall --force giv'
expect_giv_not_in_path
mv "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb" "$(pwd)/../../dist/${VERSION}/homebrew/giv.local.rb"
mv "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb.bak" "$(pwd)/../../dist/${VERSION}/homebrew/giv.rb"

echo "PASS: Homebrew install from local formula succeeded."

cd ../../
rm -rf .tmp/validate-installs
report "ALL INSTALL/UNINSTALL TESTS PASSED"
