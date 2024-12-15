import 'common.just'

bib-version := "latest"
bib-image := "quay.io/centos-bootc/bootc-image-builder:" + bib-version
bib-cache-dir := join(build-dir, 'cache', 'bib')

_bib image output_dir build_cache_dir config args: (_ensure-directory output_dir) (_ensure-directory join(build_cache_dir, 'store')) (_ensure-directory join(build_cache_dir, 'rpmmd'))
    sudo podman run -it --rm \
      --privileged \
      --pull=newer \
      --security-opt label=type:unconfined_t \
      -v '{{ config }}':/config.toml:ro \
      -v '{{ output_dir }}':/output \
      -v '{{ join(build_cache_dir, 'store') }}':/store \
      -v '{{ join(build_cache_dir, 'rpmmd') }}':/rpmmd \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      {{ bib-image }} \
      {{ args }} \
      --log-level info \
      {{ image }}
