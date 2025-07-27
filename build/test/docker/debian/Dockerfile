FROM debian:bookworm-slim

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install essential tools
RUN apt-get update && apt-get install -y \
    # System essentials
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    # Package management tools
    dpkg-dev \
    apt-utils \
    # Development tools for testing
    build-essential \
    # Python and pip
    python3 \
    python3-pip \
    python3-venv \
    # Node.js and npm
    nodejs \
    npm \
    # Snap support (may not be available on Debian)
    snapd \
    # Flatpak support
    flatpak \
    # Testing tools
    jq \
    file \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install latest Node.js from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Enable flatpak
RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Create test user
RUN useradd -m -s /bin/bash testuser \
    && usermod -aG sudo testuser \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /workspace

# Default user
USER testuser

# Test command to verify environment
CMD ["bash", "-c", "echo 'Debian test environment ready'; /bin/bash"]