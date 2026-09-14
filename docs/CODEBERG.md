# Hosting cosmic-ublue on Codeberg

## Recommended layout

Keep GitHub as the primary build and GHCR as the primary update source for now.
Use Codeberg as a source mirror first. If you later publish the image to
Codeberg, copy the already-built OCI image instead of rebuilding it.

~~~text
GitHub source -> GitHub Actions -> GHCR image
      |
      +-> Codeberg source mirror

GHCR image -> registry copy -> Codeberg container registry
~~~

## Mirror the repository

Create an empty **cosmic-ublue** repository on Codeberg, then:

~~~bash
git remote add codeberg git@codeberg.org:fery0x/cosmic-ublue.git
git push codeberg --all
git push codeberg --tags
~~~

Codeberg no longer offers general pull mirrors from other forges. Push both
remotes manually, or add a second push URL to your existing remote.

## Publish the OCI image

Forgejo, which powers Codeberg, supports OCI container images using:

~~~text
codeberg.org/OWNER/IMAGE:TAG
~~~

After creating a Codeberg access token and authenticating:

~~~bash
podman login codeberg.org
skopeo login codeberg.org
just copy-image \
  ghcr.io/fery0x/cosmic-ublue:latest \
  codeberg.org/fery0x/cosmic-ublue:latest
~~~

Sign the Codeberg registry reference separately; copying the image does not
guarantee that registry-specific Cosign signature attachments are copied:

~~~bash
cosign sign --key cosign.key codeberg.org/fery0x/cosmic-ublue@sha256:DIGEST
~~~

Never commit **cosign.key**.

To publish cosmic-ublue from Codeberg instead, change these values in
**image-template.env** before building and publishing the image:

~~~dotenv
IMAGE_REGISTRY="codeberg.org/fery0x"
SOURCE_REPOSITORY="https://codeberg.org/fery0x/cosmic-ublue"
~~~

## Storage and CI limits

Codeberg asks projects to request approval before using more than 1.5 GiB
across packages, LFS, and attachments. A desktop bootc image can exceed that
threshold, so request resources before publishing it.

Hosted Codeberg Woodpecker CI is manually approved, amd64-only, and asks users
to keep resource usage reasonable. Codeberg explicitly recommends self-hosted
agents for resource-intensive work. Build the OCI image on GitHub or a
self-hosted runner.

References:

- [Codeberg storage guidance](https://docs.codeberg.org/getting-started/faq/#what-is-the-size-limit-for-my-repositories-are-there-quotas-for-packages-lfs)
- [Codeberg CI guidance](https://docs.codeberg.org/ci/)
- [Self-hosted Forgejo Actions on Codeberg](https://docs.codeberg.org/ci/actions/)
- [Forgejo container registry](https://forgejo.org/docs/latest/user/packages/container/)
