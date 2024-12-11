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

bib-build-dirs: bib-output-dir bib-store-dir bib-rpmmd-dir

bib-output-dir:
  mkdir -p build/bib/output/base
  mkdir -p build/bib/output/beardy

bib-store-dir:
  mkdir -p build/bib/cache/store

bib-rpmmd-dir:
  mkdir -p build/bib/cache/rpmmd

bluebuild-build-dirs: bluebuild-output-dir

bluebuild-output-dir:
  mkdir -p build/bluebuild/output

bluebuild-generate-containerfile: bluebuild-build-dirs
  podman run -it --rm \
  --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate -o build/Containerfile recipes/beardy.yml

# TODO: failing with error:
#    The command 'ostree container image deploy --sysroot=/mnt/sysimage --image=/run/install/repo/beardy-os-latest --transport=oci --no-signature-verification' exited with the code 1.
bluebuild-generate-server-iso: bluebuild-build-dirs
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant server \
    --iso-name build/bluebuild/output/beardy-server.iso \
    image {{beardy-image}}

# TODO: failing with error:
#    The command 'ostree container image deploy --sysroot=/mnt/sysimage --image=/run/install/repo/beardy-os-latest --transport=oci --no-signature-verification' exited with the code 1.
bluebuild-generate-kinoite-iso: bluebuild-build-dirs
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant kinoite \
    --iso-name build/bluebuild/output/beardy-kinoite.iso \
    image {{beardy-image}}
# sudo podman run --rm --privileged \
#   --volume ./iso:/build-container-installer/build \
#   ghcr.io/jasonn3/build-container-installer:latest \
#   VERSION=41 \
#   IMAGE_NAME=beardy-os \
#   IMAGE_TAG=latest \
#   VARIANT=Kinoite \
#   IMAGE_REPO=ghcr.io/detiber

# TODO: untested
bluebuild-generate-silverblue-iso: bluebuild-build-dirs
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --variant silverblue \
    --iso-name build/bluebuild/output/beardy-silverblue.iso \
    image {{beardy-image}}


bib-version := "latest"
bib-image := "quay.io/centos-bootc/bootc-image-builder:" + bib-version

bib-base: bib-build-dirs
  echo {{beardy-image}}
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./hack/bib-img-config.toml:/config.toml:ro \
    -v ./build/bib/output/base:/output \
    -v ./build/bib/cache/store:/store \
    -v ./build/bib/cache/rpmmd:/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --local \
    --type qcow2 \
    --type raw \
    --rootfs btrfs \
    --log-level info \
    {{beardy-image}}

bib-base-iso: bib-build-dirs
  echo {{beardy-image}}
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./hack/bib-iso-config.toml:/config.toml:ro \
    -v ./build/bib/output/base:/output \
    -v ./build/bib/cache/store:/store \
    -v ./build/bib/cache/rpmmd:/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --local \
    --type iso \
    --log-level info \
    {{beardy-image}}

# TODO: failing with error at beginning of installation summary, seems to be missing some dependencies
# Generate iso image
generate-iso: bib-build-dirs
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./hack/bib-iso-config.toml:/config.toml:ro \
    -v ./build/bib/output/beardy:/output \
    -v ./build/bib/cache/store:/store \
    -v ./build/bib/cache/rpmmd:/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --type iso \
    --log-level info \
    {{beardy-image}}

# TODO: needs to be tested, requires injecting user config
# for testing: virt-install --import --disk ./output/qcow2/qcow2/disk.qcow2,format=qcow2 --cpu host-passthrough --memory 8192 --vcpus 4 --os-variant silverblue-unknown
generate-images: bib-build-dirs
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v ./hack/bib-img-config.toml:/config.toml:ro \
    -v ./build/bib/output/beardy:/output \
    -v ./build/bib/cache/store:/store \
    -v ./build/bib/cache/rpmmd:/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    --type qcow2 \
    --type raw \
    --rootfs btrfs \
    --log-level info \
    {{beardy-image}}

[group('clean')]
clean-all: clean-bib-cache clean-bib-output clean-bluebuild-output

[group('clean')]
clean-bib-cache:
  rm -rf build/bib/cache

[group('clean')]
clean-bib-output:
  rm -rf build/bib/output

[group('clean')]
clean-bluebuild-output:
  rm -rf build/bluebuild/output