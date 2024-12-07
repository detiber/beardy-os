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
