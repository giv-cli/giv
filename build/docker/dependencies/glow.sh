
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
    grep '"tag_name":' | sed -r 's/.*"([^"]+)".*/\1/')
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
install_glow() {
    if is_glow_installed; then
        echo "✔ glow already installed: $(command -v glow)"
        return
    fi
    
    echo "✗ glow not found. Installing…"
    if install_pkg; then
        echo "Installed via package manager."
    else
        install_from_github
    fi
    
    if ! is_glow_installed; then
        echo "Installation failed. See https://github.com/charmbracelet/glow#installation"
        exit 1
    fi
}

