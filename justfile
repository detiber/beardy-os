# default recipe to display help information
default:
  @just --list

beardy-version := "latest"
beardy-repo := "ghcr.io/detiber"
#beardy-image := beardy-repo + "/beardy-os:" + beardy-version

# Using main to bring in --tempdir arg, can change back to latest once that feature is released
bluebuild-version := "main"
bluebuild-image := "ghcr.io/blue-build/cli:" + bluebuild-version

butane-version := "release"
butane-image := "quay.io/coreos/butane:" + butane-version

bib-version := "latest"
bib-image := "quay.io/centos-bootc/bootc-image-builder:" + bib-version

[group('lint')]
[group('validate')]
validate-all: validate-recipes

# Validate all recipes
[group('lint')]
[group('validate')]
validate-recipes:
  for file in `ls recipes/*.yml`; do \
    just validate-recipe-for ${file}; \
  done

_validate-recipe-for recipe_def:
  podman run -it --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    {{bluebuild-image}} \
    bluebuild validate {{recipe_def}}

[group('generate')]
generate-all: generate-ignition

# Generate ignition config
[group('generate')]
[group('ignition')]
generate-ignition:
  for file in `ls hack/*.butane`; do \
    just _generate-ignition-for ${file}; \
  done

_generate-ignition-for butane_config:
  @echo {{without_extension(butane_config)}}
  podman run -i --rm \
    --pull=newer \
    {{butane-image}} \
    --pretty --strict \
    < {{butane_config}} \
    > {{without_extension(butane_config)}}.ign

common-build-dir := absolute_path("./build")
_ensure-directory dir_path:
  mkdir -p {{dir_path}}

common-bib-output-dir := join(common-build-dir, "bib", "output")
common-bib-cache-dir := join(common-build-dir, "bib", "cache")
common-bib-store-cache-dir := join(common-bib-cache-dir, "store")
common-bib-rpmmd-cache-dir := join(common-bib-cache-dir, "rpmmd")
_bib image output_dir config args: \
  (_ensure-directory common-bib-store-cache-dir) \
  (_ensure-directory common-bib-rpmmd-cache-dir)
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{config}}':/config.toml:ro \
    -v '{{output_dir}}':/output \
    -v '{{common-bib-store-cache-dir}}':/store \
    -v '{{common-bib-rpmmd-cache-dir}}':/rpmmd \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    {{bib-image}} \
    {{args}} \
    --log-level info \
    {{image}}

common-bib-image-config := absolute_path("./hack/bib-img-config.toml")
common-bib-image-args := "--type qcow2 --rootfs btrfs"
_bib-image image output_dir: \
  && (_bib image output_dir common-bib-image-config
    common-bib-image-args)

common-bib-iso-config := absolute_path("./hack/bib-iso-config.toml")
common-bib-iso-args := "--type anaconda-iso"
_bib-iso image output_dir: \
  && (_bib image output_dir common-bib-iso-config common-bib-iso-args)

bib-base-image-name := "beardy-os-base"
bib-base-image := beardy-repo + "/" \
  + bib-base-image-name + ":" + beardy-version
bib-base-image-output-dir := join(common-bib-output-dir, "base")
[group('disk images')]
[group('bib')]
bib-image-base: (_ensure-directory bib-base-image-output-dir) \
  && (_bib-image bib-base-image bib-base-image-output-dir)

[group('iso')]
[group('bib')]
bib-iso-base: (_ensure-directory bib-base-image-output-dir) \
  && (_bib-iso bib-base-image bib-base-image-output-dir)

bib-beardy-image-name := "beardy-os"
bib-beardy-image := beardy-repo + "/" \
  + bib-beardy-image-name + ":" + beardy-version
bib-beardy-image-output-dir := join(common-bib-output-dir, "beardy")
[group('disk images')]
[group('bib')]
bib-image-beardy: (_ensure-directory bib-beardy-image-output-dir) \
  && (_bib-image bib-beardy-image bib-beardy-image-output-dir)

[group('iso')]
[group('bib')]
bib-iso-beardy: (_ensure-directory bib-beardy-image-output-dir) && \
  (_bib-iso bib-beardy-image bib-beardy-image-output-dir)

common-bluebuild-output-dir := join(common-build-dir,
  "bluebuild", "output")
common-bluebuild-tmp-dir := join(common-build-dir,
  "bluebuild", "tmp")
_bluebuild-containerfile recipe output_dir:
  podman run -it --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    -v '{{output_dir}}':/output \
    {{bluebuild-image}} \
    bluebuild generate -o /output/Containerfile {{recipe}}

_bluebuild-iso recipe output_dir image_name image variant: \
  (_ensure-directory common-bluebuild-tmp-dir)
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    -v '{{output_dir}}':/output \
    -v '{{common-bluebuild-tmp-dir}}':/build_tmp \
    {{bluebuild-image}} \
    bluebuild generate-iso \
    -R podman \
    --tempdir /build_tmp \
    -o /output \
    --variant {{variant}} \
    --iso-name "{{image_name}}-{{variant}}.iso" \
    image {{image}}

bluebuild-beardy-output-dir := join(common-bluebuild-output-dir,
  "beardy")
bluebuild-beardy-recipe-file := "recipes/beardy.yml"
bluebuild-beardy-image-name := "beardy-os"
bluebuild-beardy-image := beardy-repo + "/" \
  + bluebuild-beardy-image-name + ":" + beardy-version
[group('containerfile')]
[group('bluebuild')]
bluebuild-containerfile-beardy: \
  (_ensure-directory bluebuild-beardy-output-dir) \
  && (_bluebuild-containerfile
    bluebuild-beardy-recipe-file 
    bluebuild-beardy-output-dir)

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-server: \
  (_ensure-directory bluebuild-beardy-output-dir) \
  && (_bluebuild-iso
    bluebuild-beardy-recipe-file
    bluebuild-beardy-output-dir
    bluebuild-beardy-image-name
    bluebuild-beardy-image
    "server")

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-kinoite: \
  (_ensure-directory bluebuild-beardy-output-dir) \
  && (_bluebuild-iso
    bluebuild-beardy-recipe-file
    bluebuild-beardy-output-dir
    bluebuild-beardy-image-name
    bluebuild-beardy-image
    "kinoite")

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-silverblue: \
  (_ensure-directory bluebuild-beardy-output-dir) \
  && (_bluebuild-iso
    bluebuild-beardy-recipe-file
    bluebuild-beardy-output-dir
    bluebuild-beardy-image-name
    bluebuild-beardy-image
    "silverblue")

[group('clean')]
clean-all: clean-bib-cache clean-bib-output clean-bluebuild-output

[group('clean')]
[group('bib')]
clean-bib-cache:
  rm -rf {{common-bib-cache-dir}}

[group('clean')]
[group('bib')]
clean-bib-output:
  rm -rf {{common-bib-output-dir}}

[group('clean')]
[group('bluebuild')]
clean-bluebuild-output:
  rm -rf build/bluebuild/output

coreos-installer-version := "release"
coreos-installer-image := "quay.io/coreos/coreos-installer:" \
  + coreos-installer-version
coreos-pxe-output-dir := join(common-build-dir, "coreos", "pxe")
coreos-pxe: (_ensure-directory coreos-pxe-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-pxe-output-dir}}':/data \
    -w /data \
    {{coreos-installer-image}} \
    download -f pxe

coreos-pxe-customize: (_ensure-directory coreos-pxe-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-pxe-output-dir}}':/data \
    -v '{{absolute_path("./hack/base.ign")}}':/config/config.ign \
    -w /data \
    {{coreos-installer-image}} \
    pxe customize \
    --dest-device /dev/vda \
    --dest-ignition /config/config.ign \
    -o /data/wrapped-initramfs.img \
    fedora-coreos-41.20241109.3.0-live-initramfs.x86_64.img

coreos-iso-output-dir := join(common-build-dir, "coreos", "iso")
coreos-iso: (_ensure-directory coreos-iso-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-iso-output-dir}}':/data \
    -w /data \
    {{coreos-installer-image}} \
    download -f iso

coreos-iso-customize: (_ensure-directory coreos-iso-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-iso-output-dir}}':/data \
    -v '{{absolute_path("./hack/base.ign")}}':/config/config.ign \
    -w /data \
    {{coreos-installer-image}} \
    iso customize \
    --dest-device /dev/vda \
    --dest-ignition /config/config.ign \
    -o /data/coreos-custom.iso \
    fedora-coreos-41.20241109.3.0-live.x86_64.iso

coreos-iso-rebase: (_ensure-directory coreos-iso-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-iso-output-dir}}':/data \
    -v '{{absolute_path("./hack/beardy-autorebase.ign")}}':/config/config.ign \
    -w /data \
    {{coreos-installer-image}} \
    iso customize \
    --dest-device /dev/vda \
    --dest-ignition /config/config.ign \
    -o /data/coreos-rebase-beardy.iso \
    fedora-coreos-41.20241109.3.0-live.x86_64.iso

coreos-iso-switch: (_ensure-directory coreos-iso-output-dir)
  podman run --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{coreos-iso-output-dir}}':/data \
    -v '{{absolute_path("./hack/beardy-bootc-switch.ign")}}':/config/config.ign \
    -w /data \
    {{coreos-installer-image}} \
    iso customize \
    --dest-device /dev/vda \
    --dest-ignition /config/config.ign \
    -o /data/coreos-switch-beardy.iso \
    fedora-coreos-41.20241109.3.0-live.x86_64.iso

common-bootc-output-dir := join(common-build-dir, "bootc", "output")
_bootc image args: (_ensure-directory common-bootc-output-dir)
  sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --pid=host \
    --security-opt label=type:unconfined_t \
    -e BOOTC_DIRECT_IO=on \
    -e LANG="en_US.UTF-8" \
    -v '{{common-bootc-output-dir}}':/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v /dev:/dev \
    {{image}} \
    bootc {{args}}

_bootc-create-file name: (_ensure-directory common-bootc-output-dir)
  dd of='{{common-bootc-output-dir}}/{{name}}' bs=20G seek=1 count=0

# TODO: set BOOTC_DIRECT_IO=on
bootc-install-disk image filename additional_args="": \
  (_bootc-create-file filename) \
  && (_bootc
    image
    "install to-disk --wipe --filesystem=btrfs " \
    + "--generic-image --via-loopback /output/" + filename \
    + " " + additional_args)

# bootc-base-image-name := "beardy-os-base"
# bootc-base-image := beardy-repo + "/" + bib-base-image-name + ":" + beardy-version
# bootc-base-image := "ghcr.io/ublue-os/base-main:latest"
# bootc-base-image-filename := "beardy-base.raw"
# bootc-base-install-args := "install to-disk " \
#   + " --wipe --filesystem=btrfs" \
#   + " --generic-image --via-loopback /output/" \
#   + bootc-base-image-filename
# bootc-install-disk: \
#   (_bootc-create-file bootc-base-image-filename) \
#   && (_bootc bootc-base-image bootc-base-install-args)

local-build tag containerfile additional_args="":
  sudo podman build \
    {{additional_args}} \
    -t {{tag}} \
    -f {{containerfile}} \
    .

local-build-ublue-base-name := "beardy-base"
local-build-ublue-base-image := "localhost/" \
  + local-build-ublue-base-name + ":latest"
local-build-ublue-base-containerfile := "ublue-image-template/Containerfile"
local-build-ublue-base: \
  && (local-build
    local-build-ublue-base-image
    local-build-ublue-base-containerfile)

local-build-bootc-base-name := "beardy-bootc"
local-build-bootc-base-image := "localhost/" \
  + local-build-bootc-base-name + ":latest"
local-build-bootc-base-containerfile := "bootc/Containerfile"
local-build-bootc-base: \
  && (local-build
    local-build-bootc-base-image
    local-build-bootc-base-containerfile)

local-bib-image-args := common-bib-image-args + " --local"
_local-bib-image image output_dir: \
  && (_bib
    image
    output_dir
    common-bib-image-config
    local-bib-image-args)

local-bib-iso-args := common-bib-image-args + " --local"
_local-bib-iso image output_dir: \
  && (_bib
    image
    output_dir
    common-bib-iso-config
    local-bib-iso-args)

local-bib-ublue-base-image-output-dir := join(common-bib-output-dir,
  "local", "base")
[group('disk images')]
[group('bib')]
local-bib-image-ublue-base: \
  (_ensure-directory local-bib-ublue-base-image-output-dir) \
  (local-build-ublue-base) \
  && (_local-bib-image
    local-build-ublue-base-image
    local-bib-ublue-base-image-output-dir)

[group('iso')]
[group('bib')]
local-bib-iso-ublue-base: \
  (_ensure-directory local-bib-ublue-base-image-output-dir) \
  (local-build-ublue-base) \
  && (_local-bib-iso
    local-build-ublue-base-image
    local-bib-ublue-base-image-output-dir)

local-bib-bootc-base-image-output-dir := join(common-bib-output-dir,
  "local", "bootc")
[group('disk images')]
[group('bib')]
local-bib-image-bootc-base: \
  (_ensure-directory local-bib-bootc-base-image-output-dir) \
  (local-build-bootc-base) \
  && (_local-bib-image
    local-build-bootc-base-image
    local-bib-bootc-base-image-output-dir)

[group('iso')]
[group('bib')]
local-bib-iso-bootc-base: \
  (_ensure-directory local-bib-bootc-base-image-output-dir) \
  (local-build-bootc-base) \
  && (_local-bib-iso
    local-build-bootc-base-image
    local-bib-bootc-base-image-output-dir)

local-bootc-install-ublue-base: \
  (local-build-bootc-base) \
  && (bootc-install-disk
    local-build-ublue-base-image
    "beardy-ublue.raw"
    " --skip-fetch-check")

local-bootc-install-bootc-base: \
  (local-build-bootc-base) \
  && (bootc-install-disk
    local-build-bootc-base-image
    "beardy-bootc.raw"
    " --skip-fetch-check")
