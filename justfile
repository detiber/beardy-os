# default recipe to display help information
default:
  @just --list

# Validate all recipes
validate-recipes:
  for file in `ls recipes/*.yml`; do \
    podman run -it -v '{{absolute_path(".")}}':/bluebuild --rm ghcr.io/blue-build/cli:latest bluebuild validate ${file}; \
  done

generate-ignition:
  podman pull quay.io/coreos/butane:release
  podman run -i --rm quay.io/coreos/butane:release --pretty --strict < hack/beardy-autorebase.butane > hack/beardy-autorebase.ign

bluebuild:
  sudo bluebuild generate-iso --iso-name output/beardy-os.iso image ghcr.io/detiber/beardy-os:latest

generate-images:
  sudo podman pull ghcr.io/detiber/beardy-os:latest
  mkdir -p output
  sudo podman run \
    --rm \
    -it \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v ./hack/bootc-image-builder-config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso \
    ghcr.io/detiber/beardy-os:latest

# sudo podman run --rm --privileged --volume ./iso-output:/build-container-installer/build --security-opt label=disable --pull=newer ghcr.io/lauretano/t2-atomic-bluefin:latest
# sudo docker run --rm --privileged --volume ./iso-output:/build-container-installer/build --pull=always ghcr.io/lauretano/t2-atomic-bluefin:latest
# or maybe https://wiki.archlinux.org/title/Mkosi
