import 'cosign.just'
import 'common.just'

repo_organization := "detiber"
rechunker_image := "ghcr.io/hhd-dev/rechunk:v1.0.1"

# Get Fedora Version of an image
_fedora_version base_image tag:
    #!/usr/bin/bash
    set -eou pipefail
    if [[ ! -f /tmp/manifest.json ]]; then
        if [[ "{{ tag }}" =~ stable ]]; then
            # CoreOS does not uses cosign
            skopeo inspect --retry-times 3 docker://quay.io/fedora/fedora-coreos:stable > /tmp/manifest.json
        else
            skopeo inspect --retry-times 3 docker://"{{ base_image }}:{{ tag }}" > /tmp/manifest.json
        fi
    fi
    fedora_version=$(jq -r '.Labels["ostree.linux"]' < /tmp/manifest.json | grep -oP 'fc\K[0-9]+')
    echo "${fedora_version}"

# Build Image
_build image tag base_image args: _disk-use (_header "Build Image") (verify-image base_image + ":" + `just _fedora_version '{{ base_image }}' '{{ tag }}'`) && (_footer "Build Image") _disk-use
    # Build Image
    podman build \
        --tag "{{ image }}:{{ tag }}" \
        {{ args }} \
        .

# Rechunk Image
_rechunk image tag base_image rechunk-dir: (_ensure-directory rechunk-dir) _disk-use (_header "Rechunk") && (_footer "Rechunk") _disk-use
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if image is already built
    ID=$(podman images --filter reference=localhost/"{{ image }}":"{{ tag }}" --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        just _build "{{ image }}" "{{ tag }}" "{{ base_image }}" ""
    fi

    # Load into Rootful Podman
    ID=$(just sudoif podman images --filter reference=localhost/"{{ image }}":"{{ tag }}" --format "'{{ '{{.ID}}' }}'")
    if [[ -z "$ID" ]]; then
        COPYTMP=$(mktemp -p "{{ rechunk-dir }}" -d -t podman_scp.XXXXXXXXXX)
        just sudoif TMPDIR="${COPYTMP}" podman image scp ${UID}@localhost::localhost/"{{ image }}":"{{ tag }}" root@localhost::localhost/"{{ image }}":"{{ tag }}"
        rm -rf "${COPYTMP}"
    fi

    # Prep Container
    CREF=$(just sudoif podman create localhost/"{{ image }}":"{{ tag }}" bash)
    OLD_IMAGE=$(just sudoif podman inspect $CREF | jq -r '.[].Image')
    OUT_NAME="{{ image }}_build"
    MOUNT=$(just sudoif podman mount "${CREF}")

    # Fedora Version
    fedora_version=$(just sudoif podman inspect $CREF | jq -r '.[].Config.Labels["ostree.linux"]' | grep -oP 'fc\K[0-9]+')

    # Label Version
    if [[ "{{ tag }}" =~ stable ]]; then
        VERSION="${fedora_version}.$(date +%Y%m%d)"
    else
        VERSION="{{ tag }}-${fedora_version}.$(date +%Y%m%d)"
    fi

    # # TODO: Cleanup Space during Github Action

    # Run Rechunker's Prune
    just sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --env TREE=/var/tree \
        --user 0:0 \
        "{{ rechunker_image }}" \
        /sources/rechunk/1_prune.sh

    # Run Rechunker's Create
    just sudoif podman run --rm \
        --security-opt label=disable \
        --volume "$MOUNT":/var/tree \
        --volume "cache_ostree:/var/ostree" \
        --env TREE=/var/tree \
        --env REPO=/var/ostree/repo \
        --env RESET_TIMESTAMP=1 \
        --user 0:0 \
        "{{ rechunker_image }}" \
        /sources/rechunk/2_create.sh

    # Cleanup Temp Container Reference
    just sudoif podman unmount "$CREF"
    just sudoif podman rm "$CREF"
    just sudoif podman rmi "$OLD_IMAGE"

    SHA="dedbeef"
    if [[ -z "$(git status -s)" ]]; then
        SHA=$(git rev-parse HEAD)
    fi
    # Run Rechunker
    just sudoif podman run --rm \
        --pull=newer \
        --security-opt label=disable \
        --volume "{{ rechunk-dir }}:/workspace" \
        --volume "{{ root-dir }}:/var/git" \
        --volume cache_ostree:/var/ostree \
        --env REPO=/var/ostree/repo \
        --env PREV_REF=ghcr.io/detiber/"{{ image }}":"{{ tag }}" \
        --env OUT_NAME="$OUT_NAME" \
        --env LABELS="org.opencontainers.image.title={{ image }}$'\n''io.artifacthub.package.readme-url=https://raw.githubusercontent.com/detiber/beardy-os/refs/heads/main/README.md'$'\n''io.artifacthub.package.logo-url=https://avatars.githubusercontent.com/u/120078124?s=200&v=4'$'\n'" \
        --env "DESCRIPTION='The preferred bluefin-based OS of bearded developers'" \
        --env "VERSION=${VERSION}" \
        --env VERSION_FN=/workspace/version.txt \
        --env OUT_REF="oci:$OUT_NAME" \
        --env GIT_DIR="/var/git" \
        --env REVISION="$SHA" \
        --user 0:0 \
        "{{ rechunker_image }}" \
        /sources/rechunk/3_chunk.sh

    # Fix Permissions of OCI
    if [[ "${UID}" -gt "0" ]]; then
        just sudoif chown "${UID}:${GROUPS}" -R "{{ rechunk-dir }}"
    elif [[ -n "${SUDO_UID:-}" ]]; then
        chown "${SUDO_UID}":"${SUDO_GID}" -R "{{ rechunk-dir }}"
    fi

    # Remove cache_ostree
    just sudoif podman volume rm cache_ostree

    # Show OCI Labels
    just sudoif skopeo inspect oci:"{{ rechunk-dir }}"/"${OUT_NAME}" | jq -r '.Labels'

# Load OCI into Podman Store
_load-rechunk image tag rechunk-dir: _disk-use (_header "Load Rechunk") && (_footer "Load Rechunk") _disk-use
    #!/usr/bin/bash
    set -eou pipefail

    # Load Image
    OUT_NAME="{{ image }}_build"
    IMAGE=$(podman pull oci:"{{ rechunk-dir }}"/"${OUT_NAME}")
    podman tag ${IMAGE} localhost/"{{ image }}":{{ tag }}

    # Cleanup
    just sudoif "rm -rf ${OUT_NAME}*"
    just sudoif "rm -f previous.manifest.json"

# Secureboot Check
[group('Utility')]
_secureboot image tag: _disk-use (_header "Secureboot") && (_footer "Secureboot") _disk-use
    #!/usr/bin/bash
    set -eoux pipefail

    # Get the vmlinuz to check
    kernel_release=$(podman inspect "{{ image }}":"{{ tag }}" | jq -r '.[].Config.Labels["ostree.linux"]')
    TMP=$(podman create "{{ image }}":"{{ tag }}" bash)
    podman cp "$TMP":/usr/lib/modules/"${kernel_release}"/vmlinuz /tmp/vmlinuz
    podman rm "$TMP"

    # Get the Public Certificates
    curl --retry 3 -Lo /tmp/kernel-sign.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key.der
    curl --retry 3 -Lo /tmp/akmods.der https://github.com/ublue-os/kernel-cache/raw/main/certs/public_key_2.der
    openssl x509 -in /tmp/kernel-sign.der -out /tmp/kernel-sign.crt
    openssl x509 -in /tmp/akmods.der -out /tmp/akmods.crt

    # Make sure we have sbverify
    CMD="$(command -v sbverify)"
    if [[ -z "${CMD:-}" ]]; then
        temp_name="sbverify-${RANDOM}"
        podman run -dt \
            --entrypoint /bin/sh \
            --volume /tmp/vmlinuz:/tmp/vmlinuz:z \
            --volume /tmp/kernel-sign.crt:/tmp/kernel-sign.crt:z \
            --volume /tmp/akmods.crt:/tmp/akmods.crt:z \
            --name ${temp_name} \
            alpine:edge
        podman exec ${temp_name} apk add sbsigntool
        CMD="podman exec ${temp_name} /usr/bin/sbverify"
    fi

    # Confirm that Signatures Are Good
    $CMD --list /tmp/vmlinuz
    returncode=0
    if ! $CMD --cert /tmp/kernel-sign.crt /tmp/vmlinuz || ! $CMD --cert /tmp/akmods.crt /tmp/vmlinuz; then
        echo "Secureboot Signature Failed...."
        returncode=1
    fi
    if [[ -n "${temp_name:-}" ]]; then
        podman rm -f "${temp_name}"
    fi
    exit "$returncode"
