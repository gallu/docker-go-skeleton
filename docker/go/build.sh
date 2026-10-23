#!/bin/sh
set -eu
check-app.sh
name=${GO_BINARY_NAME:-app}
case "$name" in
    .|..|*[!a-zA-Z0-9._-]*|'')
        echo 'GO_BINARY_NAME must be a filename using a-z, A-Z, 0-9, dot, underscore or hyphen.' >&2
        exit 1 ;;
esac
mkdir -p /dist
# 同じファイルシステム内で置き換え、失敗時は既存の正常な成果物を保つ。
stage=$(mktemp -d /dist/.build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
trap 'exit 1' HUP INT TERM
export GOOS=${GO_BUILD_OS:-linux} GOARCH=${GO_BUILD_ARCH:-amd64} CGO_ENABLED=${CGO_ENABLED:-0}
target=${GO_BUILD_TARGET:-.}
package=$(go list -f '{{.Name}}' "$target")
if [ "$package" != main ]; then
    echo 'GO_BUILD_TARGET must select exactly one main package.' >&2
    exit 1
fi
go build -trimpath -o "$stage/$name" "$target"
mv -f "$stage/$name" "/dist/$name"
echo "Built /dist/$name ($GOOS/$GOARCH)"
