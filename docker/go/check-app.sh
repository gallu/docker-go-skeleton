#!/bin/sh
set -eu
if [ ! -f go.mod ]; then
    echo 'Go application is not initialized.' >&2
    echo 'Please create src/go.mod and a Go application.' >&2
    echo 'Example: cd src && go mod init example.com/myapp' >&2
    exit 1
fi
