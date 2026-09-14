# cosmic-ublue

cosmic-ublue is a focused Universal Blue bootc image built from
`ghcr.io/ublue-os/base-main:44`. It adds the Fedora COSMIC desktop, a small
set of first-party COSMIC applications, and Universal Blue's Homebrew
integration.

The intended software model is:

- graphical applications, including browsers: COSMIC Store, Flatpak, and Flathub

No web browser is included in the host image. Install your preferred browser
through COSMIC Store/Flathub after first boot.

Podman and Distrobox remain available, but the rootful Podman API socket is
not enabled automatically. If an application needs the API, enable the rootless
user socket with `systemctl --user enable --now podman.socket`.
- command-line applications: Homebrew
- development environments: Podman and Distrobox
- host packages: the desktop, drivers, codecs, and system integration

## Image contents

cosmic-ublue adds the following Fedora packages to `base-main`:

| Package | Purpose |
| --- | --- |
| `cosmic-session` | COSMIC session and its required desktop components |
| `cosmic-settings` | Settings, including the supported appearance and theme editor |
| `cosmic-edit` | COSMIC text editor |
| `cosmic-monitor` | COSMIC system monitor |
| `cosmic-player` | COSMIC media player |
| `cosmic-store` | COSMIC software store |

`cosmic-session` brings in the required COSMIC stack, including Files,
Terminal, Settings, portals, the compositor, shell components, and greeter.
The other applications in the table are kept explicit so that they cannot
silently disappear if Fedora changes the session package's dependencies.

There is no separate supported `cosmic-theme-editor` Fedora package. The old
upstream repository with that name was an unfinished prototype and is now
archived. The maintained theme editor is the Appearance page in COSMIC
Settings, which cosmic-ublue installs explicitly as `cosmic-settings`.

cosmic-ublue otherwise inherits the Universal Blue base. That includes the
container and update plumbing used for Podman, Distrobox, Flathub, `ujust`, and
image updates. The Homebrew system files come from
`ghcr.io/ublue-os/brew:latest`.

## Installation model

cosmic-ublue deliberately has no ISO, Anaconda configuration, or disk-image
build. It is an OCI system image. First install and boot a compatible Fedora
Atomic or Universal Blue system, then switch that machine to cosmic-ublue.

Fedora COSMIC Atomic 44 is the closest seed installation, but it is not a base
layer that remains underneath cosmic-ublue. After the first boot:

1. Confirm that the [cosmic-ublue container package](https://github.com/fery0x/cosmic-ublue/pkgs/container/cosmic-ublue)
   is public and the latest `Build container image` workflow succeeded.
2. Inspect the current deployment:

   ```bash
   sudo bootc status
   ```

3. Stage cosmic-ublue as the next deployment:

   ```bash
   sudo bootc switch ghcr.io/fery0x/cosmic-ublue:latest
   ```

4. Reboot and confirm the new image:

   ```bash
   sudo systemctl reboot
   sudo bootc status
   ```

### What the switch replaces and preserves

`bootc switch` stages a new deployment from the complete cosmic-ublue image; it
does not install cosmic-ublue on top of all packages baked into the seed image.
Consequently, host applications that existed only in the old image are not
expected to appear in the new deployment. cosmic-ublue's immutable
operating-system tree comes from `base-main:44` plus the packages installed by
this repository.

Machine state in `/etc` and `/var` is preserved. `/etc` is carried forward with
OSTree's three-way merge, while `/var` contains persistent state such as home
directories. In normal layouts this also preserves system and per-user
Flatpaks, rootful and rootless containers, documents, and user configuration.
Back up important data before any operating-system migration regardless.

The currently running deployment is not changed in place. If cosmic-ublue does
not boot, select the previous deployment in the boot menu. From a working
system, the following stages the previous deployment for the next boot:

```bash
sudo bootc rollback
sudo systemctl reboot
```

This is the image-first path documented by Universal Blue. Installer and disk
image workflows in the general image template are optional conveniences and
are intentionally outside cosmic-ublue's scope.

## Updates

After the switch, the machine tracks
`ghcr.io/fery0x/cosmic-ublue:latest`. Universal Blue's inherited update services
can stage newly published images, or an update can be requested manually:

```bash
sudo bootc upgrade
```

## Image signing

The GitHub workflow signs each published image digest with the repository's
Cosign key. The public key is committed as `cosign.pub`; the private key belongs
only in the GitHub Actions secret named `SIGNING_SECRET`.

Before the first release, generate the key pair and configure that secret as
described by the [Universal Blue image template](https://github.com/ublue-os/image-template#step-2a-creating-a-cosign-key).
Never commit `cosign.key`.

## Build locally

On a Universal Blue or Fedora bootc host with `just` and Podman:

```bash
just check
just build
```

To publish the local `latest` image after authenticating to GHCR:

```bash
just publish ghcr.io/fery0x latest
```

The normal release path is the GitHub workflow, which checks the repository,
builds and verifies the image, rechunks it, signs its digest, and pushes it.

## Repository layout

- `Containerfile`: selects the UBlue foundation and composes cosmic-ublue
- `build_files/build.sh`: installs COSMIC and enables host services
- `image-template.env`: image name, registry, tag, and OCI metadata
- `Justfile`: local checks, image builds, rechunking, and registry helpers
- `.github/workflows/build.yml`: builds, verifies, and publishes the OCI image
- `docs/DESIGN.md`: researched scope and package-boundary decisions
- `docs/CODEBERG.md`: optional source-mirror and registry-copy notes
- `cosign.pub`: public verification key for published images

## Upstream references

- [Universal Blue base-image installation guide](https://universal-blue.discourse.group/t/how-to-install-universal-blues-base-images/868)
- [Universal Blue image template](https://github.com/ublue-os/image-template)
- [Universal Blue base images](https://github.com/ublue-os/main)
- [Fedora COSMIC Atomic](https://fedoraproject.org/atomic-desktops/cosmic/)
- [bootc upgrade, switch, and rollback](https://bootc-dev.github.io/bootc/upgrades.html)
- [bootc filesystem semantics](https://bootc-dev.github.io/bootc/filesystem.html)
- [Fedora COSMIC session package](https://packages.fedoraproject.org/pkgs/cosmic-session/cosmic-session/)
- [Fedora COSMIC Settings package](https://packages.fedoraproject.org/pkgs/cosmic-settings/cosmic-settings/)
- [Fedora COSMIC Monitor package](https://packages.fedoraproject.org/pkgs/cosmic-monitor/cosmic-monitor/)
- [System76 COSMIC applications](https://system76.com/cosmic/apps)
