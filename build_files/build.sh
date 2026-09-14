#!/usr/bin/bash

set -ouex pipefail

# Fedora's cosmic-session package supplies the COSMIC session and its required
# desktop components, including Files, Terminal and Settings. Keep Settings
# explicit because its Appearance page is COSMIC's supported theme editor.
# Edit, Monitor, Player and Store are separate first-party applications, so add
# them explicitly. Weak dependencies stay disabled to keep the host package set
# intentional and reproducible.
dnf5 install -y --setopt=install_weak_deps=False \
    cosmic-edit \
    cosmic-monitor \
    cosmic-player \
    cosmic-session \
    cosmic-settings \
    cosmic-store

# /var is persistent and is not replaced on bootc upgrades. Recreate the
# runtime state required by COSMIC dependencies on every system with tmpfiles
# instead of baking package-scriptlet output into the container image.
install -Dm0644 \
    /ctx/cosmic-ublue-tmpfiles.conf \
    /usr/lib/tmpfiles.d/cosmic-ublue.conf

# base-main can boot to a TTY. cosmic-ublue is a desktop image, so make the
# graphical target and COSMIC Greeter the default login path.
systemctl set-default graphical.target
systemctl enable cosmic-greeter.service

# Podman is part of the Fedora Atomic/UBlue platform. Distrobox is already
# included by base-main; enabling the socket makes container workflows ready.
systemctl enable podman.socket

# Activate the Homebrew integration copied from ghcr.io/ublue-os/brew.
systemctl preset brew-setup.service
systemctl preset brew-update.timer
systemctl preset brew-upgrade.timer

# base-main already configures full Flathub and UBlue update/ujust plumbing.
dnf5 clean all

# Package installation leaves transient state in /var. It must not be shipped
# in a bootc image because /var persists independently of image deployments.
rm -rf \
    /var/lib/dnf \
    /var/lib/fprint \
    /var/lib/greetd \
    /var/lib/tuned
