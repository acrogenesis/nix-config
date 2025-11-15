#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnused nix-prefetch jq

set -euo pipefail

pkg_dir="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
pkg_file="$pkg_dir/default.nix"

update_version() {
  local new_version="$1"
  sed -i "s/version = \".*\";/version = \"${new_version}\";/" "$pkg_file"
}

update_hash() {
  local new_version="$1"
  local url="https://github.com/Faustvii/Readarr/releases/download/v${new_version}/Readarr.develop.${new_version}.linux-musl-x64.tar.gz"
  local hash
  hash="$(nix-prefetch-url --type sha256 "$url")"
  sed -i "s|x86_64-linux = \".*\";|x86_64-linux = \"${hash}\";|" "$pkg_file"
}

current_version() {
  sed -n 's/^[[:space:]]*version = "\(.*\)";/\1/p' "$pkg_file"
}

latest_version() {
  curl -s https://api.github.com/repos/Faustvii/Readarr/releases \
    | jq -r '.[0].tag_name' \
    | sed 's/^v//'
}

main() {
  local current latest
  current="$(current_version | head -n1)"
  latest="$(latest_version)"

  if [[ -z "$latest" || "$latest" == "null" ]]; then
    echo "Failed to detect latest release tag" >&2
    exit 1
  fi

  if [[ "$current" == "$latest" ]]; then
    echo "readarr-faustvii is already up-to-date (${current})"
    exit 0
  fi

  echo "Updating readarr-faustvii ${current} -> ${latest}"
  update_version "$latest"
  update_hash "$latest"
}

main "$@"
