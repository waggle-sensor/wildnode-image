# required argument
ARG ROOTFS_IMAGE
# rootfs
FROM ${ROOTFS_IMAGE} as rootfs

# BUILD Environment
FROM amd64/ubuntu:bionic-20200921

RUN apt-get update && apt-get install -y \
    qemu-user-static

# Enable running Nvidia artifact creation tools
RUN apt-get update && apt-get install -y \
    libperl4-corelibs-perl \
    python

# Other tools for image creation
RUN apt-get update && apt-get install -y \
    jq \
    pigz \
    pbzip2

RUN mkdir -p /build/rootfs

# source rootfs
COPY --from=rootfs / /build/rootfs

RUN mkdir -p /build/l4t/

# Nvidia artifact creation tools check this environment variable for 'root' user
ENV USER=root

COPY create_image.sh .
