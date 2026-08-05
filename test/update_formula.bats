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
