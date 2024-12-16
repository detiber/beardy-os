import 'common.just'

iso-cache-dir := "TODO"
iso_builder_image := "ghcr.io/jasonn3/build-container-installer:v1.2.3"

# Build ISO
_build-iso $source_image_ref $out_dir out_filename: (_ensure-directory iso-cache-dir) (_ensure-directory out_dir)
    #!/usr/bin/bash
    set -eoux pipefail

     if [[ -f "{{ join(out_dir, out_filename) }}" || -f "{{ join(out_dir, out_filename) }}-CHECKSUM" ]]; then
        echo "ERROR - ISO or Checksum already exist. Please mv or rm to build new ISO"
        exit 1
    fi

    if [[ "${source_image_ref}" == localhost/* ]]; then
        IMAGE_FULL=localhost/"${image_name}":"${tag}"
        IMAGE_REPO=localhost
        ID=$(podman images --filter reference=localhost/"${image_name}":"${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ -z "$ID" ]]; then
            just build "$image" "$tag" "$flavor"
        fi
    else
        IMAGE_FULL=ghcr.io/detiber/"${image_name}":"${tag}"
        IMAGE_REPO=ghcr.io/detiber
        podman pull "${IMAGE_FULL}"
    fi

    # Fedora Version
    FEDORA_VERSION=$(podman inspect ${IMAGE_FULL} | jq -r '.[]["Config"]["Labels"]["ostree.linux"]' | grep -oP 'fc\K[0-9]+')

    # Load Image into rootful podman
    if [[ "${UID}" -gt 0 && "${source_image_ref}" == localhost/* ]]; then
        COPYTMP=$(mktemp -p "{{ iso-cache-dir }}" -d -t podman_scp.XXXXXXXXXX)
        just sudoif podman image scp "${UID}"@localhost::"${IMAGE_FULL}" root@localhost::"${IMAGE_FULL}"
        rm -rf "${COPYTMP}"
    fi

    FLATPAK_DIR_SHORTNAME="beardy_flatpaks"

    # Generate Flatpak List
    TEMP_FLATPAK_INSTALL_DIR="$(mktemp -d -p {{ iso-cache-dir }} flatpak-XXXXX)"
    flatpak_refs=()
    while IFS= read -r line; do
        flatpak_refs+=("$line")
    done < "${FLATPAK_DIR_SHORTNAME}/flatpaks"

    # Add DX Flatpaks if needed
    if [[ "${image_name}" =~ dx ]]; then
        while IFS= read -r line; do
            flatpak_refs+=("$line")
        done < "dx_flatpaks/flatpaks"
    fi

    echo "Flatpak refs: ${flatpak_refs[@]}"

    # Generate Install Script for Flatpaks
    tee "${TEMP_FLATPAK_INSTALL_DIR}/install-flatpaks.sh"<<EOF
    mkdir -p /flatpak/flatpak /flatpak/triggers
    mkdir -p /var/tmp
    chmod -R 1777 /var/tmp
    flatpak config --system --set languages "*"
    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --system -y flathub ${flatpak_refs[@]}
    ostree refs --repo=\${FLATPAK_SYSTEM_DIR}/repo | grep '^deploy/' | grep -v 'org\.freedesktop\.Platform\.openh264' | sed 's/^deploy\///g' > /output/flatpaks-with-deps
    EOF

    # Create Flatpak List with dependencies
    flatpak_list_args=()
    flatpak_list_args+=("--rm" "--privileged")
    flatpak_list_args+=("--entrypoint" "/usr/bin/bash")
    flatpak_list_args+=("--env" "FLATPAK_SYSTEM_DIR=/flatpak/flatpak")
    flatpak_list_args+=("--env" "FLATPAK_TRIGGERSDIR=/flatpak/triggers")
    flatpak_list_args+=("--volume" "${out_dir}:/output")
    flatpak_list_args+=("--volume" "${TEMP_FLATPAK_INSTALL_DIR}:/temp_flatpak_install_dir")
    flatpak_list_args+=("${IMAGE_FULL}" /temp_flatpak_install_dir/install-flatpaks.sh)

    if [[ ! -f "${out_dir}/flatpaks-with-deps" ]]; then
        podman run "${flatpak_list_args[@]}"
    else
        echo "WARNING - Reusing previous determined flatpaks-with-deps"
    fi

    # List Flatpaks with Dependencies
    cat "${out_dir}/flatpaks-with-deps"

    # Build ISO
    iso_build_args=()
    iso_build_args+=("--rm" "--privileged" "--pull=newer")
    if [[ "${source_image_ref}" == localhost/* ]]; then
    	iso_build_args+=(--volume "/var/lib/containers/storage:/var/lib/containers/storage")
    fi
    iso_build_args+=(--volume "${out_dir}:/github/workspace/build")
    iso_build_args+=("{{ iso_builder_image }}")
    iso_build_args+=(ARCH="x86_64")
    iso_build_args+=(ENROLLMENT_PASSWORD="universalblue")
    iso_build_args+=(FLATPAK_REMOTE_REFS_DIR="/github/workspace/build")
    iso_build_args+=(IMAGE_NAME="${image_name}")
    iso_build_args+=(IMAGE_REPO="${IMAGE_REPO}")
    iso_build_args+=(IMAGE_SIGNED="true")
    if [[ "${source_image_ref}" == localhost/* ]]; then
    	iso_build_args+=(IMAGE_SRC="containers-storage:${IMAGE_FULL}")
    fi
    iso_build_args+=(IMAGE_TAG="${tag}")
    iso_build_args+=(ISO_NAME="/github/workspace/build/${image_name}-${tag}.iso")
    iso_build_args+=(SECURE_BOOT_KEY_URL="https://github.com/ublue-os/akmods/raw/main/certs/public_key.der")
    iso_build_args+=(VARIANT="Silverblue")
    iso_build_args+=(VERSION="${FEDORA_VERSION}")
    iso_build_args+=(WEB_UI="false")

    just sudoif podman run "${iso_build_args[@]}"

    if [[ "${UID}" -gt "0" ]]; then
        just sudoif chown "${UID}:${GROUPS}" -R "${out_dir}"
        just sudoif chown "${UID}:${GROUPS}" -R "{{ iso-cache-dir }}"
    elif [[ -n "${SUDO_UID:-}" ]]; then
        chown "${SUDO_UID}":"${SUDO_GID}" -R "${out_dir}"
        chown "${SUDO_UID}":"${SUDO_GID}" -R "{{ iso-cache-dir }}"
    fi
