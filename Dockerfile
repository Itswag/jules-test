# Using Debian Bullseye Slim as a base for the builder
FROM debian:bullseye-slim AS builder

# Install build dependencies for Skopeo & other tools
RUN apt-get update && apt-get install -y --no-install-recommends     git     golang-go     libgpgme-dev     libassuan-dev     libbtrfs-dev     libdevmapper-dev     pkg-config     make     gcc     ca-certificates     && rm -rf /var/lib/apt/lists/*

# Build Skopeo from source
# Using a known stable version for skopeo, adjust if necessary
ENV SKOPEO_VERSION=v1.14.0
RUN git clone --depth 1 --branch ${SKOPEO_VERSION} https://github.com/containers/skopeo.git /tmp/skopeo     && cd /tmp/skopeo     # Build skopeo binary statically if possible, or ensure all runtime libs are in the final image
    # For simplicity, we build with CGO_ENABLED=1 which might link dynamically to some system libs for e.g. archive support
    && make GO_DOCKERIZED= GOBIN=/usr/local/bin CGO_ENABLED=1     && mv /usr/local/bin/skopeo /usr/local/bin/skopeo_built     && cd /     && rm -rf /tmp/skopeo

# --- Final Image ---
FROM debian:bullseye-slim

# Install runtime dependencies for Skopeo and other utilities
RUN apt-get update && apt-get install -y --no-install-recommends     curl     wget     tar     ca-certificates     libgpgme11     libassuan0     libbtrfs0     libdevmapper1.02.1     # Add any other specific runtime dependencies identified from skopeo build
    && rm -rf /var/lib/apt/lists/*

# Copy Skopeo binary from builder stage
COPY --from=builder /usr/local/bin/skopeo_built /usr/local/bin/skopeo

# Install Kaniko executor
# Using a known stable version for Kaniko, adjust if necessary
ENV KANIKO_VERSION=v1.11.0
RUN wget -q https://github.com/GoogleContainerTools/kaniko/releases/download/${KANIKO_VERSION}/executor-linux-amd64 -O /kaniko/executor     && chmod +x /kaniko/executor
    # The main script calls /kaniko/executor, so this location is fine.

# Ensure all tools are executable and in PATH if necessary
# /usr/local/bin and /kaniko/ are typical, ensure scripts use full paths or PATH is set.
ENV PATH=/usr/local/bin:/usr/bin:/bin:/kaniko

# Create a non-root user (optional, but good practice)
# RUN groupadd -r appgroup && useradd -r -g appgroup -s /sbin/nologin -c "App User" appuser
# USER appuser
# Note: Kaniko might need root to manipulate image layers unless run with specific flags/setup.
# For simplicity in this context, we'll keep it running as root, which is common in CI/CD jobs.

# Default command (useful for testing the image)
CMD ["sh", "-c", "echo 'Combined tools image ready. Kaniko version:'; /kaniko/executor --version; echo 'Skopeo version:'; skopeo --version"]
