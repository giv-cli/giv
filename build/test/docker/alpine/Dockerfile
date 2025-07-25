FROM alpine:3.18

# Update package list and install essential tools
RUN apk update && apk add --no-cache \
    # System essentials
    curl \
    wget \
    git \
    ca-certificates \
    # Development tools for testing
    build-base \
    # Python and pip
    python3 \
    py3-pip \
    # Node.js and npm
    nodejs \
    npm \
    # Testing tools
    jq \
    file \
    tree \
    # Additional tools
    bash \
    sudo \
    shadow

# Create test user
RUN adduser -D -s /bin/bash testuser \
    && addgroup testuser wheel \
    && echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set working directory
WORKDIR /workspace

# Default user
USER testuser

# Test command to verify environment
CMD ["bash", "-c", "echo 'Alpine test environment ready'; /bin/bash"]