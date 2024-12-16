beardy-version := "latest"
beardy-repo := "ghcr.io/detiber"
root-dir := canonicalize(parent_directory(source_directory()))
build-dir := join(root-dir, 'build')

_ensure-directory dir_path:
    mkdir -p {{ dir_path }}

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# Generate Default Tag
[group('Utility')]
generate-default-tag tag="latest" ghcr="0":
    #!/usr/bin/bash
    set -eou pipefail

    # Default Tag
    if [[ "{{ tag }}" =~ stable && "{{ ghcr }}" == "1" ]]; then
        DEFAULT_TAG="stable-daily"
    elif [[ "{{ tag }}" =~ stable && "{{ ghcr }}" == "0" ]]; then
        DEFAULT_TAG="stable"
    else
        DEFAULT_TAG="{{ tag }}"
    fi

    echo "${DEFAULT_TAG}"

_disk-use: (_header "Disk Use") && (_footer "Disk Use")
    just sudoif du -hs /var/tmp /tmp
    find {{ build-dir }} -type d -exec du -hs {} \; | sort -h
    podman system df
    just sudoif podman system df

_header title:
    @echo ""
    @echo '============================================'
    @echo "Start: {{ title }}"
    @echo '============================================'

_footer title:
    @echo '============================================'
    @echo "End: {{ title }}"
    @echo '============================================'
    @echo ""
