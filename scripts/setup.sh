#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p src dist
echo 'Created src/ and dist/. Existing files and permissions are unchanged.'
