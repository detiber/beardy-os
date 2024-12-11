# default recipe to display help information
default:
  @just --list

beardy-version := "latest"
beardy-repo := "ghcr.io/detiber"
#beardy-image := beardy-repo + "/beardy-os:" + beardy-version

bluebuild-version := "latest"
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
    just generate-ignition-for ${file}; \
  done

_generate-ignition-for butane_config:
  @echo {{without_extension(butane_config)}}
  podman run -i --rm \
    --pull=newer \
    {{butane-image}} \
    --pretty --strict < {{butane_config}} > {{without_extension(butane_config)}}.ign

common-build-dir := absolute_path("./build")
_ensure-directory dir_path:
  mkdir -p {{dir_path}}

common-bib-output-dir := join(common-build-dir, "bib", "output")
common-bib-cache-dir := join(common-build-dir, "bib", "cache")
common-bib-store-cache-dir := join(common-bib-cache-dir, "store")
common-bib-rpmmd-cache-dir := join(common-bib-cache-dir, "rpmmd")
_bib image output_dir config args: (_ensure-directory common-bib-store-cache-dir) (_ensure-directory common-bib-rpmmd-cache-dir)
  podman run --it --rm \
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
_bib-image image output_dir: && (_bib image output_dir common-bib-image-config common-bib-image-args)

common-bib-iso-config := absolute_path("./hack/bib-iso-config.toml")
common-bib-iso-args := "--type iso"
_bib-iso image output_dir: && (_bib image output_dir common-bib-iso-config common-bib-iso-args)

bib-base-image-name := "beardy-os-base"
bib-base-image := beardy-repo + "/" + bib-base-image-name + ":" + beardy-version
bib-base-image-output-dir := join(common-bib-output-dir, "base")
[group('disk images')]
[group('bib')]
bib-image-base: (_ensure-directory bib-base-image-output-dir) && (_bib-image bib-base-image bib-base-image-output-dir)

[group('iso')]
[group('bib')]
bib-iso-base: (_ensure-directory bib-base-image-output-dir) && (_bib-iso bib-base-image bib-base-image-output-dir)

bib-beardy-image-name := "beardy-os"
bib-beardy-image := beardy-repo + "/" + bib-beardy-image-name + ":" + beardy-version
bib-beardy-image-output-dir := join(common-bib-output-dir, "beardy")
[group('disk images')]
[group('bib')]
bib-image-beardy: (_ensure-directory bib-beardy-image-output-dir) && (_bib-image bib-beardy-image bib-beardy-image-output-dir)

[group('iso')]
[group('bib')]
bib-iso-beardy: (_ensure-directory bib-beardy-image-output-dir) && (_bib-iso bib-beardy-image bib-beardy-image-output-dir)

common-bluebuild-output-dir := join(common-build-dir, "bluebuild", "output")
_bluebuild-containerfile recipe output_dir:
  podman run -it --rm \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    -v '{{output_dir}}':/output \
    {{bluebuild-image}} \
    bluebuild generate -o /output/Containerfile {{recipe}}

_bluebuild-iso recipe output_dir image_name image variant:
  echo sudo podman run -it --rm \
    --privileged \
    --pull=newer \
    --security-opt label=type:unconfined_t \
    -v '{{absolute_path(".")}}':/bluebuild \
    -v '{{output_dir}}':/output \
    bluebuild generate-iso \
    -R podman \
    --variant {{variant}} \
    --iso-name "/output/{{image_name}}-{{variant}}.iso" \
    image {{image}}

bluebuild-beardy-output-dir := join(common-bluebuild-output-dir, "beardy")
bluebuild-beardy-recipe-file := "recipes/beardy.yml"
bluebuild-beardy-image-name := "beardy-os"
bluebuild-beardy-image := beardy-repo + "/" + bluebuild-beardy-image-name + ":" + beardy-version
[group('containerfile')]
[group('bluebuild')]
bluebuild-containerfile-beardy: (_ensure-directory bluebuild-beardy-output-dir) && (_bluebuild-containerfile bluebuild-beardy-recipe-file bluebuild-beardy-output-dir)

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-server: (_ensure-directory bluebuild-beardy-output-dir) && (_bluebuild-iso bluebuild-beardy-recipe-file bluebuild-beardy-output-dir bluebuild-beardy-image-name bluebuild-beardy-image "server")

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-kinoite: (_ensure-directory bluebuild-beardy-output-dir) && (_bluebuild-iso bluebuild-beardy-recipe-file bluebuild-beardy-output-dir bluebuild-beardy-image-name bluebuild-beardy-image "kinoite")

[group('iso')]
[group('bluebuild')]
bluebuild-iso-beardy-silverblue: (_ensure-directory bluebuild-beardy-output-dir) && (_bluebuild-iso bluebuild-beardy-recipe-file bluebuild-beardy-output-dir bluebuild-beardy-image-name bluebuild-beardy-image "silverblue")

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
