wolf-api-schema:
    sudo curl --unix-socket /var/run/wolf/wolf.sock http://localhost/api/v1/openapi-schema | jq

wolf-debug-steam:
    sudo podman run --rm -it \
        --device=/dev/dri/renderD128 \
        --device=/dev/dri/card1 \
        -ipc=host \
        -privileged \
        -cap-add=ALL \
        -security-opt seccomp=unconfined \
        -e XDG_RUNTIME_DIR=/tmp \
        -v ${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:/tmp/${WAYLAND_DISPLAY}:rw \
        -e XDG_SESSION_TYPE=wayland \
        -e WAYLAND_DISPLAY=${WAYLAND_DISPLAY} \
        -e RUN_SWAY=true \
        -v /tmp/SteamGOWData:/home/retro/ \
        ghcr.io/games-on-whales/steam:fix-steam-mesa

wolf-debug:
    sudo podman stop WolfPulseAudio || true
    sudo podman rm WolfPulseAudio || true
    sudo podman run --rm \
        --name wolf \
        --privileged \
        --network=host \
        --ipc=host \
        --cap-add=ALL \
        --device-cgroup-rule "c 13:* rmw" \
        --device /dev/dri \
        --device /dev/uinput \
        --device /dev/uhid \
        -v /tmp/sockets:/tmp/sockets:rw \
        -v /etc/wolf:/etc/wolf:rw \
        -v /run/podman/podman.sock:/var/run/docker.sock:ro \
        -v /dev/input:/dev/input:ro \
        -v /run/udev:/run/udev:rw \
        --security-opt seccomp=unconfined \
        ghcr.io/games-on-whales/wolf:stable
