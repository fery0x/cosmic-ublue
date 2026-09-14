# cosmic-ublue: Universal Blue base + Fedora COSMIC + UBlue Homebrew.
#
# Software model (matching Aurora's philosophy):
#   GUI apps        -> Flatpak / Flathub
#   CLI apps        -> Homebrew
#   Dev/pet envs    -> Podman + Distrobox
#   Host image      -> OS, COSMIC, drivers and system integration

# Universal Blue's supported Homebrew integration for custom bootc images.
FROM ghcr.io/ublue-os/brew:latest AS brew

# Build inputs are mounted during the build and are not left in the image.
FROM scratch AS ctx
COPY build_files /

# Generic Universal Blue foundation. Fedora 44 is the current UBlue latest
# release and the target for Fedora's current COSMIC packages.
FROM ghcr.io/ublue-os/base-main:44

# Homebrew tarball, setup/update services, shell integration and tmpfiles.
COPY --from=brew /system_files/ /

# Add COSMIC and configure the cosmic-ublue host services.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN --mount=type=tmpfs,target=/run --network=none \
    bootc container lint --fatal-warnings --no-truncate
