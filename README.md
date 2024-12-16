# beardy-os
[![build-beardy-base](https://github.com/detiber/beardy-os/actions/workflows/base-build.yml/badge.svg?branch=main)](https://github.com/detiber/beardy-os/actions/workflows/base-build.yml)
[![Latest Images](https://github.com/detiber/beardy-os/actions/workflows/bluefin-latest.yml/badge.svg)](https://github.com/detiber/beardy-os/actions/workflows/bluefin-latest.yml)
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/beardy-os)](https://artifacthub.io/packages/search?repo=beardy-os)

## NOTE:

This repo is used for building os images layered upon various upstream bootc/ublue-os based images. Use at your own risk, and without any support.

## Installation

> **Warning**  
> [This is an experimental feature](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable), try at your own discretion.

To rebase an existing atomic Fedora installation to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies installed:
  ```
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/detiber/beardy-os:latest
  ```
- Reboot to complete the rebase:
  ```
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/detiber/beardy-os:latest
  ```
- Reboot again to complete the installation
  ```
  systemctl reboot
  ```

The `latest` tag will automatically point to the latest build. That build will still always use the Fedora version specified in `recipe.yml`, so you won't get accidentally updated to the next major version.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/detiber/beardy-os
```
