FROM archlinux:latest

# Update package database and install essential tools
RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    # System essentials
    curl \
    wget \
    git \
    ca-certificates \
    # Development tools for testing
    base-devel \
    # Python and pip
    python \
    python-pip \
    # Node.js and npm
    nodejs \
    npm \
    # Snap support (from AUR - may need manual build)
    # snapd \
    # Flatpak support
    flatpak \
    # Testing tools
    jq \
    file \
    tree \
    # Additional tools
    which \
    sudo \
    && pacman -Scc --noconfirm

# Enable flatpak
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Create test user
RUN useradd -m -s /bin/bash testuser \
    && usermod -aG wheel testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /workspace

# Default user
USER testuser

# Test command to verify environment
CMD ["bash", "-c", "echo 'Arch test environment ready'; /bin/bash"]