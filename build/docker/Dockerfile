FROM debian:bookworm-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        curl \
        bash \
    && rm -rf /var/lib/apt/lists/*

# # ---- Install Glow ----
# ENV GLOW_VERSION="2.1.1"
# RUN curl -fsSL "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_linux_amd64.deb" -o /tmp/glow.deb \
#     && apt-get update \
#     && apt-get install -y /tmp/glow.deb \
#     && rm /tmp/glow.deb

# Copy your built files into place (from the repo root at build time)
# Assume you have these in the build context!
COPY src/giv.sh /usr/local/bin/giv
COPY src/*.sh /usr/local/lib/giv/
COPY templates/ /usr/local/share/giv/templates/
COPY docs/ /usr/local/share/giv/docs/

RUN chmod +x /usr/local/bin/giv

# Set up environment
ENV GIV_LIB_DIR="/usr/local/lib/giv"
ENV GIV_TEMPLATE_DIR="/usr/local/share/giv/templates"
ENV GIV_DOCS_DIR="/usr/local/share/giv/docs"
ENV PATH="/usr/local/bin:$PATH"

# Test it works
RUN giv --help || true

# Use bash shell by default
SHELL ["/bin/bash", "-c"]

WORKDIR /workspace

ENTRYPOINT ["giv"]
CMD ["--help"]
