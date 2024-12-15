mod bootc 'variants/bootc/justfile'
mod bluefin 'variants/bluefin/justfile'

import 'just/common.just'

# default recipe to display help information
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find {{ root-dir }} -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: justfile"
    just --unstable --fmt --check -f justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find {{ root-dir }} -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: justfile"
    just --unstable --fmt -f justfile || { exit 1; }
