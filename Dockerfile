# Ubuntu-based build environment for AmberG350
FROM ubuntu:latest

# Update the system and install necessary packages
RUN apt-get update && \
    apt-get install -y \
    build-essential \
    git \
    python3 \
    rsync \
    squashfs-tools \
    wget \
    unzip \
    p7zip-full

# Set the working directory
WORKDIR /build

# Set user to a non-root user
RUN useradd -m builder && \
    chown -R builder:builder /build

USER builder

# Default command
CMD ["/bin/bash"]