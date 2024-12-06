# default recipe to display help information
default:
  @just --list

# Validate all recipes
validate-recipes:
  for file in `ls recipes/*.yml`; do \
    podman run -it -v '{{absolute_path(".")}}':/bluebuild --rm ghcr.io/blue-build/cli:latest bluebuild validate ${file}; \
  done
