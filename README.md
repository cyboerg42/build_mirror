# build_mirror
bash wrapper to compile a bunch of ubuntu pkgs from source

dependencies : dpkg-buildpackage, apt, sqlite3, sudo

1) run ./init.sh

2) build ubuntu base -> run ./build_ubuntu_base.sh

or

2) cd scripts
3) ./sources.sh my.manifest

or (ignore version from manifest)

2) cd scripts
3) ./newest_sources.sh my.manifest
4) sudo ./build.sh

or (complex manifest)

2) cd scripts
3) ./complex_manifest_sources.sh my.complex.manifest
4) sudo ./build.sh
