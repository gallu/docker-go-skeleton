#!/bin/sh
set -eu
check-app.sh
mkdir -p /tmp/air
exec air -c /etc/air.toml
