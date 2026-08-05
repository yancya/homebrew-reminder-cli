#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${TEMPLATE:-$REPO_ROOT/Formula/reminder-cli.rb.tmpl}"
FORMULA="${FORMULA:-$REPO_ROOT/Formula/reminder-cli.rb}"
UPSTREAM_REPO="yancya/reminder-cli"
ASSET_NAME="reminder-cli-macos.tar.gz"

render_formula() {
  local template="$1" version="$2" sha256="$3"
  sed -e "s@{{VERSION}}@${version}@g" -e "s@{{SHA256}}@${sha256}@g" "$template"
}

extract_version_from_formula() {
  local formula="$1"
  grep -o '/download/[^/]*/' "$formula" | head -1 | sed -e 's#/download/##' -e 's#/##'
}

fetch_latest_release() {
  curl -sSf "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"
}

download_asset() {
  local url="$1" dest="$2"
  curl -sSfL -o "$dest" "$url"
}

# Guards render_formula against tags containing '/' (breaks the sed delimiter)
# or '&' (sed replacement-text metacharacter) reaching the generated Formula.
validate_version() {
  local version="$1"
  [[ "$version" =~ ^v[0-9][A-Za-z0-9._-]*$ ]]
}

validate_sha256() {
  local sha256="$1"
  [[ "$sha256" =~ ^[0-9a-f]{64}$ ]]
}

main() {
  local release_json latest_version download_url tmp_tarball sha256 current_version tmp_formula

  release_json="$(fetch_latest_release)"
  latest_version="$(printf '%s' "$release_json" | jq -r '.tag_name // empty')"
  download_url="$(printf '%s' "$release_json" | jq -r --arg n "$ASSET_NAME" '[.assets[]? | select(.name == $n) | .browser_download_url][0] // empty')"

  if [ -z "$latest_version" ] || [ -z "$download_url" ]; then
    echo "failed to determine latest release (tag/asset) from ${UPSTREAM_REPO}" >&2
    exit 1
  fi

  if ! validate_version "$latest_version"; then
    echo "unexpected version format from ${UPSTREAM_REPO}: ${latest_version}" >&2
    exit 1
  fi

  current_version="$(extract_version_from_formula "$FORMULA" || true)"

  if [ "$latest_version" = "$current_version" ]; then
    echo "no-op: already at ${current_version}"
    return 0
  fi

  tmp_tarball="$(mktemp)"
  if ! download_asset "$download_url" "$tmp_tarball"; then
    rm -f "$tmp_tarball"
    echo "failed to download asset: ${download_url}" >&2
    exit 1
  fi
  sha256="$(shasum -a 256 "$tmp_tarball" | awk '{print $1}')"
  rm -f "$tmp_tarball"

  if ! validate_sha256 "$sha256"; then
    echo "unexpected sha256 computed for downloaded asset: ${sha256}" >&2
    exit 1
  fi

  tmp_formula="$(mktemp)"
  render_formula "$TEMPLATE" "$latest_version" "$sha256" > "$tmp_formula"
  chmod 644 "$tmp_formula"
  mv "$tmp_formula" "$FORMULA"
  echo "updated: ${current_version:-none} -> ${latest_version}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
