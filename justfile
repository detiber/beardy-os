# default recipe to display help information
default:
  @just --list

beardy-version := "latest"
beardy-image := "ghcr.io/detiber/beardy-os:" + beardy-version

bluebuild-version := "latest"
bluebuild-image := "ghcr.io/blue-build/cli:" + bluebuild-version

# Validate all recipes
validate-recipes:
  for file in `ls recipes/*.yml`; do \
    podman run -it --rm \
      --pull=newer \
      --security-opt label=type:unconfined_t \
      -v '{{absolute_path(".")}}':/bluebuild \
      {{bluebuild-image}} \
      bluebuild validate ${file}; \
  done

butane-version := "release"
butane-image := "quay.io/coreos/butane:" + butane-version

# Generate ignition config
generate-ignition:
  podman run -i --rm \
    --pull=newer \
    {{butane-image}} \
    --pretty --strict < hack/beardy-autorebase.butane > hack/beardy-autorebase.ign

output-dir:
  mkdir -p output

bluebuild-generate-iso: output-dir
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant server \
    --iso-name output/beardy-server.iso \
    image {{beardy-image}}
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant kinoite \
    --iso-name output/beardy-kinoite.iso \
    image {{beardy-image}}
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant silverblue \
    --iso-name output/beardy-silverblue.iso \
    image {{beardy-image}}


bib-version := "latest"
bib-image := "quay.io/centos-bootc/bootc-image-builder:" + bib-version

# Generate iso image
generate-iso: output-dir
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v ./hack/bootc-image-builder-config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --type iso \
    {{beardy-image}}

generate-images: output-dir
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./output:/output \
    -v ./hack/bootc-image-builder-config.toml:/config.toml:ro \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --type qcow2 \
    --type raw \
    --rootfs btrfs \
    {{beardy-image}}
