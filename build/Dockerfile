FROM ubuntu:24.04

# Install core utilities and dependencies
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    rpm \
    curl \
    wget \
    git \
    jq \
    npm \
    snapd \
    python3 \
    python3-pip \
    ruby \
    ruby-dev \
    flatpak-builder \
    lsb-release \
    ca-certificates \
    gnupg2 \
    xz-utils \
    sudo \
    locales \
    unzip


# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
# Install snapd (for snap builds; install snaps at runtime)
#RUN apt-get update && apt-get install -y --no-install-recommends snapd && rm -rf /var/lib/apt/lists/*
# NOTE: To use snapcraft, start the container and run:
#   snap install core && snap install snapcraft --classic

# Install fpm (package builder for deb/rpm)
RUN gem install --no-document fpm

# Install bats (for shell testing)
RUN npm install -g bats

# Install Homebrew (for homebrew builds, on Linux)
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
RUN brew update || true

# Install GitHub CLI (gh)
RUN type -p gh || (curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh)

# Set workdir
WORKDIR /workspace

# Default entrypoint and command
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["if [ -f ./build/build.sh ]; then ./build/build.sh; else exec /bin/bash; fi"]