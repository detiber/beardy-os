# Notes

## Kickstart

- kickstart config option for installing a disk img vs packages: https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html#liveimg
- option for ostree installations: https://pykickstart.readthedocs.io/en/latest/kickstart-docs.html#ostreecontainer

## bootc

- kernel arguments: https://containers.github.io/bootc/building/kernel-arguments.html
  - injected at install time: https://containers.github.io/bootc/building/kernel-arguments.html#kernel-arguments-injected-at-installation-time
- users and groups: https://containers.github.io/bootc/building/users-and-groups.html
- API: https://containers.github.io/bootc/bootc-via-api.html


## thoughts on streamlining

- current methods of generating iso and disk images suitable for running a vm or host is a bit painful
- pxe methods seem to mostly target coreos, which doesn't align well with the ublue (or bootc) images at this time, as far as I can tell.
- it seems like there should be a way convert the container to a running disk image without jumping through so many hoops (with multiple install/build cycles).
- pxe/disk/iso based bootstrap -> merge install time config (anaconda/kickstart/...) from kernel command line/network/etc -> deploy ostree-based image -> reboot/kexec
  - seems like a pxe-boot image containing anaconda *could* do this
  - current iso-based systems basically seem to deploy an entire separate os for bootstrapping
  - even configuring auto-rebase through kickstart takes too long, multiple deploy, write, reboot stages
  - leverage something like capt-based deployment???

  ## build-container-installer

  - possibly use https://github.com/JasonN3/build-container-installer/wiki/development_vscode, for windows-based dev?
  - additional_templates - need examples/docs...  lorax templates, but lorax docs are pretty obtuse
  - extra_boot_params - maybe can use to inject additional anaconda config, similart to bootc-image-builder config?
  - how to inject LANG to work around iso install issue related to locale????

## anaconda
  - logging: https://docs.fedoraproject.org/en-US/quick-docs/anaconda-logging/#_introduction
    - `ctrl-b-<tab number>` works for tmux session when `Alt+Tab` is unavailable (such as accessing vm console via Cockpit)

## rabbit holes:
  - using osbuild tooling?
    - building ostree images: https://osbuild.org/docs/on-premises/commandline/building-ostree-images
    - blueprint config ref: https://osbuild.org/docs/user-guide/blueprint-reference
    - output formats: https://osbuild.org/docs/user-guide/introduction#image-builder-output-formats
    - bootc-image-builder: https://osbuild.org/docs/bootc/
  - bootable containers upstream: https://containers.github.io/bootable/
  - bootc upstream: https://containers.github.io/bootc/
  - ostree upstream: https://ostreedev.github.io/ostree/
  