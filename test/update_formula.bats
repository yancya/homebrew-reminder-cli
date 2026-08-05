#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  source "$SCRIPT_DIR/script/update-formula.sh"
}

@test "render_formula substitutes VERSION and SHA256 placeholders" {
  tmpl="$(mktemp)"
  cat > "$tmpl" <<'EOF'
url "https://example.com/{{VERSION}}/asset.tar.gz"
sha256 "{{SHA256}}"
EOF
  result="$(render_formula "$tmpl" "v1.2.3" "deadbeef")"
  rm -f "$tmpl"

  [[ "$result" == *'v1.2.3/asset.tar.gz'* ]]
  [[ "$result" == *'sha256 "deadbeef"'* ]]
}

@test "render_formula does not touch Ruby string interpolation" {
  tmpl="$(mktemp)"
  cat > "$tmpl" <<'EOF'
test do
  assert_match version.to_s, shell_output("#{bin}/reminder-cli --version")
end
EOF
  result="$(render_formula "$tmpl" "v1.2.3" "deadbeef")"
  rm -f "$tmpl"

  [[ "$result" == *'#{bin}/reminder-cli'* ]]
}

@test "extract_version_from_formula reads the release tag from the download url" {
  formula="$(mktemp)"
  cat > "$formula" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF
  result="$(extract_version_from_formula "$formula")"
  rm -f "$formula"

  [ "$result" = "v1.0.1" ]
}

@test "main renders an updated formula when a newer release is available" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF

  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "v1.1.0", "assets": [{"name": "reminder-cli-macos.tar.gz", "browser_download_url": "https://example.com/v1.1.0/reminder-cli-macos.tar.gz"}]}
JSON
  }

  download_asset() {
    local dest="$2"
    printf 'fake-binary-contents' > "$dest"
  }

  expected_sha256="$(printf 'fake-binary-contents' | shasum -a 256 | awk '{print $1}')"

  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated: v1.0.1 -> v1.1.0"* ]]
  grep -q 'download/v1.1.0/' "$FORMULA"
  grep -q "sha256 \"${expected_sha256}\"" "$FORMULA"

  rm -rf "$work"
}

@test "main picks the exact asset by name, not a substring match" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF

  # a sidecar asset whose name *contains* the real asset name as a substring
  # must not be picked over (or instead of) the exact match.
  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "v1.1.0", "assets": [
  {"name": "reminder-cli-macos.tar.gz.sha256", "browser_download_url": "https://example.com/v1.1.0/reminder-cli-macos.tar.gz.sha256"},
  {"name": "reminder-cli-macos.tar.gz", "browser_download_url": "https://example.com/v1.1.0/reminder-cli-macos.tar.gz"}
]}
JSON
  }

  received_url_file="$work/received_url"
  download_asset() {
    local url="$1" dest="$2"
    printf '%s' "$url" > "$received_url_file"
    printf 'fake-binary-contents' > "$dest"
  }

  run main
  [ "$status" -eq 0 ]
  [ "$(cat "$received_url_file")" = "https://example.com/v1.1.0/reminder-cli-macos.tar.gz" ]

  rm -rf "$work"
}

@test "main fails loudly instead of silently updating when the API returns no matching asset" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF

  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "v1.1.0", "assets": [{"name": "some-other-file.zip", "browser_download_url": "https://example.com/other"}]}
JSON
  }

  run main
  [ "$status" -ne 0 ]
  before="$(cat "$FORMULA")"
  [[ "$before" == *"v1.0.1"* ]]

  rm -rf "$work"
}

@test "main rejects an unexpected version format instead of rendering a broken formula" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF

  # a tag containing a slash would otherwise break the sed substitution
  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "release/1.1.0", "assets": [{"name": "reminder-cli-macos.tar.gz", "browser_download_url": "https://example.com/reminder-cli-macos.tar.gz"}]}
JSON
  }

  download_asset() {
    echo "should not be called" >&2
    return 1
  }

  run main
  [ "$status" -ne 0 ]

  rm -rf "$work"
}

@test "validate_version accepts vX.Y.Z-style tags and rejects tags with a slash" {
  validate_version "v1.1.0"
  ! validate_version "release/1.1.0"
}

@test "validate_sha256 accepts a 64-char hex digest and rejects anything else" {
  validate_sha256 "$(printf 'x' | shasum -a 256 | awk '{print $1}')"
  ! validate_sha256 "not-a-sha256"
}

@test "main is a no-op when the formula is already at the latest version" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.1.0/reminder-cli-macos.tar.gz"
EOF

  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "v1.1.0", "assets": [{"name": "reminder-cli-macos.tar.gz", "browser_download_url": "https://example.com/v1.1.0/reminder-cli-macos.tar.gz"}]}
JSON
  }

  download_asset() {
    echo "should not be called" >&2
    return 1
  }

  before="$(cat "$FORMULA")"
  run main
  [ "$status" -eq 0 ]
  [[ "$output" == *"no-op: already at v1.1.0"* ]]
  [ "$(cat "$FORMULA")" = "$before" ]

  rm -rf "$work"
}

@test "main writes the formula world-readable (matches pre-existing file permissions)" {
  work="$(mktemp -d)"
  TEMPLATE="$SCRIPT_DIR/Formula/reminder-cli.rb.tmpl"
  FORMULA="$work/reminder-cli.rb"
  cat > "$FORMULA" <<'EOF'
  url "https://github.com/yancya/reminder-cli/releases/download/v1.0.1/reminder-cli-macos.tar.gz"
EOF
  chmod 644 "$FORMULA"

  fetch_latest_release() {
    cat <<'JSON'
{"tag_name": "v1.1.0", "assets": [{"name": "reminder-cli-macos.tar.gz", "browser_download_url": "https://example.com/v1.1.0/reminder-cli-macos.tar.gz"}]}
JSON
  }

  download_asset() {
    printf 'fake-binary-contents' > "$2"
  }

  run main
  [ "$status" -eq 0 ]
  perms="$(stat -f '%OLp' "$FORMULA" 2>/dev/null || stat -c '%a' "$FORMULA")"
  [ "$perms" = "644" ]

  rm -rf "$work"
}
