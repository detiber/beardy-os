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


#       -e WOLF_RENDER_NODE=/dev/dri/renderD129 \
#       -e WOLF_ENCODER_NODE=/dev/dri/renderD129 \
