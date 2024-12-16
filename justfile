mod bootc 'variants/bootc/justfile'
mod bluefin 'variants/bluefin/justfile'
mod ublue 'variants/ublue/justfile'

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
    find {{ root-dir }} -type f -name "justfile" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt --check -f $file
    done

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find {{ root-dir }} -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    find {{ root-dir }} -type f -name "justfile" | while read -r file; do
        echo "Checking syntax: $file"
        just --unstable --fmt -f $file
    done
