#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/Formula/reminder-cli.rb.tmpl"
FORMULA="$REPO_ROOT/Formula/reminder-cli.rb"
UPSTREAM_REPO="yancya/reminder-cli"
ASSET_NAME="reminder-cli-macos.tar.gz"

render_formula() {
  local template="$1" version="$2" sha256="$3"
  sed -e "s/{{VERSION}}/${version}/g" -e "s/{{SHA256}}/${sha256}/g" "$template"
}

extract_version_from_formula() {
  local formula="$1"
  grep -o '/download/[^/]*/' "$formula" | head -1 | sed -e 's#/download/##' -e 's#/##'
}

fetch_latest_release() {
  curl -sf "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"
}

download_asset() {
  local url="$1" dest="$2"
  curl -sfL -o "$dest" "$url"
}

main() {
  local release_json latest_version download_url tmp_tarball sha256 current_version

  release_json="$(fetch_latest_release)"
  latest_version="$(printf '%s' "$release_json" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
  download_url="$(printf '%s' "$release_json" | grep '"browser_download_url"' | grep "$ASSET_NAME" | head -1 | sed -E 's/.*"browser_download_url": *"([^"]+)".*/\1/')"

  if [ -z "$latest_version" ] || [ -z "$download_url" ]; then
    echo "failed to determine latest release from ${UPSTREAM_REPO}" >&2
    exit 1
  fi

  current_version="$(extract_version_from_formula "$FORMULA")"

  if [ "$latest_version" = "$current_version" ]; then
    echo "no-op: already at ${current_version}"
    exit 0
  fi

  tmp_tarball="$(mktemp)"
  download_asset "$download_url" "$tmp_tarball"
  sha256="$(shasum -a 256 "$tmp_tarball" | awk '{print $1}')"
  rm -f "$tmp_tarball"

  render_formula "$TEMPLATE" "$latest_version" "$sha256" > "$FORMULA"
  echo "updated: ${current_version} -> ${latest_version}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
