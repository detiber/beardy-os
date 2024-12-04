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
