FROM fedora:39

# Update package list and install essential tools
RUN dnf update -y && dnf install -y \
    # System essentials
    curl \
    wget \
    git \
    ca-certificates \
    # Development tools for testing
    gcc \
    gcc-c++ \
    make \
    # RPM development tools
    rpm-build \
    rpm-devel \
    rpmdevtools \
    # Python and pip
    python3 \
    python3-pip \
    # Node.js and npm
    nodejs \
    npm \
    # Snap support
    snapd \
    # Flatpak support
    flatpak \
    # Testing tools
    jq \
    file \
    tree \
    # Additional tools
    which \
    sudo \
    && dnf clean all

# Enable snap and flatpak
RUN systemctl enable snapd || true
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
CMD ["bash", "-c", "echo 'Fedora test environment ready'; /bin/bash"]