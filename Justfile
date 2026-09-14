set dotenv-filename := "image-template.env"
set dotenv-load

export image_name := env_var("IMAGE_NAME")
export image_registry := env_var("IMAGE_REGISTRY")
export repo_organization := env_var("REPO_ORGANIZATION")
export source_repository := env_var("SOURCE_REPOSITORY")
export image_desc := env_var("IMAGE_DESC")
export default_tag := env_var("DEFAULT_TAG")

[private]
default:
    @just --list

[group('Quality')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt --check -f Justfile
    bash -n build_files/build.sh
    if command -v shellcheck >/dev/null; then
        shellcheck build_files/build.sh
    fi

    # cosmic-ublue is distributed only as an OCI system image. Fail if optional
    # installer/disk-image template machinery is accidentally reintroduced.
    forbidden_paths=(
      installer
      disk_config
      iso.toml
      image.toml
      docs/INSTALLER.md
      .github/workflows/build-disk.yml
    )
    for path in "${forbidden_paths[@]}"; do
        if [[ -e "${path}" ]]; then
            echo "unexpected installer artifact: ${path}" >&2
            exit 1
        fi
    done

[group('Container')]
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    labels=(
      --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      --label "org.opencontainers.image.description={{ image_desc }}"
      --label "org.opencontainers.image.documentation={{ source_repository }}#readme"
      --label "org.opencontainers.image.licenses=Apache-2.0"
      --label "org.opencontainers.image.source={{ source_repository }}"
      --label "org.opencontainers.image.title={{ image_name }}"
      --label "org.opencontainers.image.url={{ source_repository }}"
      --label "org.opencontainers.image.vendor={{ repo_organization }}"
    )
    version="{{ tag }}"

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_sha=$(git rev-parse --short HEAD)
        labels+=(--label "org.opencontainers.image.revision=${git_sha}")
        if [[ -z "$(git status --short)" ]]; then
            version="{{ tag }}.$(date +%Y%m%d)-${git_sha}"
        fi
    fi
    labels+=(--label "org.opencontainers.image.version=${version}")

    podman build \
      --pull=newer \
      --tag "{{ target_image }}:{{ tag }}" \
      --file Containerfile \
      "${labels[@]}" \
      .

[group('Container')]
ostree-rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    graphroot=$(podman info --format '{{ '{{.Store.GraphRoot}}' }}')
    podman run --rm --pull=never --privileged \
      --mount=type=image,src="{{ target_image }}:{{ tag }}",target=/rpm-ostree \
      --mount=type=bind,src="${graphroot}",target=/run/host-container-storage,rw \
      --mount=type=tmpfs,target=/run/rpm-ostree-storage \
      --entrypoint /usr/bin/rpm-ostree \
      "localhost/{{ target_image }}:{{ tag }}" \
      compose build-chunked-oci \
      --max-layers 127 \
      --format-version=2 \
      --bootc \
      --rootfs /rpm-ostree \
      --output "containers-storage:[overlay@/run/host-container-storage+/run/rpm-ostree-storage]localhost/{{ target_image }}:{{ tag }}"

[private]
image_name $target_image=image_name:
    @echo "{{ target_image }}"

[private]
generate-default-tag:
    @echo "{{ default_tag }}"

[private]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail

    date_tag=$(date +%Y%m%d)
    tags=("${date_tag}" "{{ tag }}" "{{ tag }}-${date_tag}")
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [[ -z "$(git status --short)" ]]; then
        git_sha=$(git rev-parse --short HEAD)
        tags+=("{{ tag }}-${git_sha}" "{{ tag }}-${date_tag}-${git_sha}" "${date_tag}-${git_sha}")
    fi
    printf '%s ' "${tags[@]}"
    printf '\n'

[private]
tag-images $target_image $source_tag tags:
    #!/usr/bin/env bash
    set -euo pipefail

    read -ra alias_tags <<<"{{ tags }}"
    for alias_tag in "${alias_tags[@]}"; do
        podman tag "{{ target_image }}:{{ source_tag }}" "{{ target_image }}:${alias_tag}"
    done

[group('Registry')]
publish $registry=image_registry $tag=default_tag:
    #!/usr/bin/env bash
    set -euo pipefail
    destination="{{ registry }}/{{ image_name }}:{{ tag }}"
    podman tag "{{ image_name }}:{{ tag }}" "${destination}"
    podman push "${destination}"

[group('Registry')]
copy-image $source $destination:
    skopeo copy --all "docker://{{ source }}" "docker://{{ destination }}"
