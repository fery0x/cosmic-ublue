# cosmic-ublue design and package audit

Research checked: 2026-09-14. Target: Fedora 44, using
`ghcr.io/ublue-os/base-main:44`.

## Result

cosmic-ublue is an OCI system image meant to be selected with `bootc switch`
after a compatible Fedora Atomic or Universal Blue installation has booted. It
is not an installer product and contains no ISO, Anaconda, disk-layout, or
disk-image generation path.

The image has one graphical environment: Fedora's packaged COSMIC desktop. Its
only direct desktop RPMs are:

```text
cosmic-edit
cosmic-monitor
cosmic-player
cosmic-session
cosmic-settings
cosmic-store
```

All are installed from Fedora 44 repositories. Weak dependencies are disabled
to make the requested host package boundary explicit.

## Package decisions

| Capability | How cosmic-ublue supplies it | Reason |
| --- | --- | --- |
| COSMIC desktop | `cosmic-session` | Fedora's session package declares the required compositor, shell, portal, Files, Terminal, Settings, greeter, and related dependencies. |
| Theme editing | `cosmic-settings` | The maintained editor is Settings → Desktop → Appearance. Fedora ships an Appearance desktop entry in this package. |
| Text editing | `cosmic-edit` | First-party COSMIC app, separate from the session package. |
| System monitoring | `cosmic-monitor` | Current first-party app, packaged for Fedora 44. |
| Media playback | `cosmic-player` | First-party COSMIC app, separate from the session package. |
| Software browsing | `cosmic-store` | First-party COSMIC app, separate from the session package. |
| CLI applications | UBlue Homebrew image | Keeps mutable CLI tools outside the immutable host RPM set. |
| Development containers | inherited base plus enabled `podman.socket` | `base-main` supplies Podman/Distrobox plumbing; cosmic-ublue enables the socket. |
| General GUI applications and browsers | COSMIC Store / Flatpak / Flathub | Keeps replaceable end-user applications out of the host image; inherited Firefox RPMs are removed. |

Installing the COSMIC package group was rejected for this image because its
membership is broader and can change independently of cosmic-ublue's intended
app set. Installing the six named packages makes review and CI verification
exact.

## Theme editor finding

The name `cosmic-theme-editor` still appears in the COSMIC umbrella README, but
the linked repository was only a `0.0.1` GTK/Rust boilerplate, never published a
release, and was archived on 2026-04-28. It is not present in Fedora's current
COSMIC source-package set. Adding `dnf5 install cosmic-theme-editor` would make
the cosmic-ublue build fail rather than add a usable application.

Theme creation and import/export live in the maintained `cosmic-settings`
Appearance implementation. Fedora 44's `cosmic-settings` package includes
`com.system76.CosmicSettings.Appearance.desktop` and the COSMIC theme
configuration data. cosmic-ublue therefore installs and verifies that package
and desktop entry explicitly. This fulfills the theme-editor requirement using
the supported implementation.

Primary evidence:

- [COSMIC Settings in Fedora 44](https://packages.fedoraproject.org/pkgs/cosmic-settings/cosmic-settings/fedora-44-updates.html)
- [COSMIC Settings appearance implementation](https://github.com/pop-os/cosmic-settings/tree/master/cosmic-settings/src/pages/desktop/appearance)
- [archived theme-editor prototype](https://github.com/pop-os/cosmic-theme-editor)
- [Fedora Rawhide source-package index](https://dl.fedoraproject.org/pub/fedora/linux/development/rawhide/Everything/source/tree/Packages/c/)

## Monitor and application finding

COSMIC Monitor is a supported upstream component and Fedora 44 package. Player,
Edit, and Store are also independent packages rather than guaranteed contents
of `cosmic-session`; they remain named explicitly in the image recipe.

Primary evidence:

- [COSMIC component list](https://github.com/pop-os/cosmic-epoch#components-of-cosmic-desktop)
- [COSMIC Monitor in Fedora 44](https://packages.fedoraproject.org/pkgs/cosmic-monitor/cosmic-monitor/fedora-44-updates.html)
- [COSMIC Player in Fedora 44](https://packages.fedoraproject.org/pkgs/cosmic-player/cosmic-player/fedora-44-updates.html)
- [COSMIC Edit in Fedora 44](https://packages.fedoraproject.org/pkgs/cosmic-edit/cosmic-edit/fedora-44-updates.html)
- [COSMIC Store in Fedora 44](https://packages.fedoraproject.org/pkgs/cosmic-store/cosmic-store/fedora-44-updates.html)
- [System76's featured COSMIC apps](https://system76.com/cosmic/apps)

## Deployment boundary

`bootc switch` changes the OCI image reference tracked by the machine and
stages a complete new deployment. It has upgrade semantics; the running root is
not modified in place. The next deployment's immutable OS content comes from
cosmic-ublue, not from a union with the seed image's packaged desktop
applications.

The switch preserves `/etc` and `/var`. Persistent `/etc` uses a three-way
merge. `/var` normally holds `/var/home`, system Flatpaks, container storage,
and other machine state. This is why installing Fedora COSMIC Atomic 44 first
is a bootstrap route, not an instruction to maintain two stacked desktops.

Primary evidence:

- [bootc upgrade, switch, and rollback](https://bootc-dev.github.io/bootc/upgrades.html)
- [bootc filesystem and `/etc` merge semantics](https://bootc-dev.github.io/bootc/filesystem.html)
- [Universal Blue base-image installation guide](https://universal-blue.discourse.group/t/how-to-install-universal-blues-base-images/868)

## Deliberately absent

- installer and ISO configuration
- disk-image workflows and partition layouts
- additional desktop sessions or compositors
- third-party COPR repositories
- source-built desktop applications
- host-layered general-purpose GUI applications

The `just check` recipe rejects known installer and disk-image template paths.
The container build runs `bootc container lint --fatal-warnings`. CI then checks
all six direct COSMIC RPMs, the Monitor and Player executables, the Settings
Appearance desktop entry, and the enabled COSMIC Greeter before publishing.

## Remaining build boundary

Repository checks can validate syntax, scope, and workflow assertions. Only an
actual container build can resolve the live Fedora/UBlue repositories and run
`bootc container lint`; the GitHub workflow is the authoritative integration
test and release path.
