#!/bin/sh
set -eu
exec go build -o /tmp/air/app "${GO_BUILD_TARGET:-.}"
