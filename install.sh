#!/bin/sh
#
# Install the Cleotic CLI.
#
# Typical usage:
#   curl -fsSL https://raw.githubusercontent.com/Cleotic/cleotic-cli/main/install.sh | sh
#
# Pin a version:
#   curl -fsSL https://raw.githubusercontent.com/Cleotic/cleotic-cli/main/install.sh | CLEOTIC_VERSION=v0.1.0 sh
#
# Install to a specific directory:
#   CLEOTIC_INSTALL_DIR="$HOME/.local/bin" sh install.sh
#
# Respects:
#   CLEOTIC_VERSION      Release version to install. Defaults to latest.
#   CLEOTIC_INSTALL_DIR  Destination directory. Defaults to $HOME/.local/bin.
#   CLEOTIC_REPO         GitHub repo for release assets. Defaults to Cleotic/cleotic-cli.
#   CLEOTIC_BASE_URL     Full base URL for release assets. Used for testing/staging.
#
set -eu

default_repo="Cleotic/cleotic-cli"
repo="${CLEOTIC_REPO:-$default_repo}"
version="${CLEOTIC_VERSION:-latest}"
base_url="${CLEOTIC_BASE_URL:-}"

log() {
  printf '%s\n' "$*"
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

default_install_dir() {
  [ -n "${HOME:-}" ] || fail "HOME is not set. Set CLEOTIC_INSTALL_DIR to a directory you can write to."
  printf '%s\n' "$HOME/.local/bin"
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

path_contains() {
  dir="$1"
  case ":$PATH:" in
    *":$dir:"*) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  os="$(uname -s)"
  case "$os" in
    Darwin) printf 'mac-os' ;;
    Linux) printf 'linux' ;;
    *) fail "unsupported operating system: $os" ;;
  esac
}

detect_arch() {
  arch="$(uname -m)"
  case "$arch" in
    arm64|aarch64) printf 'arm64' ;;
    x86_64|amd64) printf 'x86_64' ;;
    *) fail "unsupported architecture: $arch" ;;
  esac
}

sha256_file() {
  file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  fail "missing required command: sha256sum or shasum"
}

asset_version_from_release_version() {
  case "$1" in
    v*) printf '%s\n' "${1#v}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

release_tag_from_version() {
  case "$1" in
    v*) printf '%s\n' "$1" ;;
    *) printf 'v%s\n' "$1" ;;
  esac
}

download() {
  url="$1"
  output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$output"
    return
  fi
  if command -v fetch >/dev/null 2>&1; then
    fetch -q "$url" -o "$output"
    return
  fi
  fail "missing required command: curl, wget, or fetch"
}

resolve_latest_version() {
  latest_json="${tmpdir}/latest-release.json"
  download "https://api.github.com/repos/${repo}/releases/latest" "$latest_json"
  latest_tag="$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$latest_json" | head -n 1)"
  [ -n "$latest_tag" ] || fail "could not resolve latest release for ${repo}"
  printf '%s\n' "$latest_tag"
}

usage() {
  cat <<EOF
Install the Cleotic CLI.

Usage:
  sh install.sh [--help]

Environment:
  CLEOTIC_VERSION      Release version to install. Defaults to latest.
  CLEOTIC_INSTALL_DIR  Destination directory. Defaults to \$HOME/.local/bin.
  CLEOTIC_REPO         GitHub repo for release assets. Defaults to ${default_repo}.
  CLEOTIC_BASE_URL     Full base URL for release assets. Used for testing/staging.

Examples:
  CLEOTIC_VERSION=v0.1.0 sh install.sh
  CLEOTIC_INSTALL_DIR="\$HOME/.local/bin" sh install.sh
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    fail "unknown option: $1"
    ;;
esac

platform="$(detect_os)"
arch="$(detect_arch)"
install_dir="${CLEOTIC_INSTALL_DIR:-}"
if [ -z "$install_dir" ]; then
  install_dir="$(default_install_dir)"
fi

need tar
need awk
need mktemp
need sed

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

if [ "$version" = "latest" ]; then
  [ -z "$base_url" ] || fail "CLEOTIC_BASE_URL requires CLEOTIC_VERSION when release asset names include the version"
  version="$(resolve_latest_version)"
  log "Resolved latest release: ${version}"
fi

release_version="$(release_tag_from_version "$version")"
asset_version="$(asset_version_from_release_version "$release_version")"
archive="cleotic_${asset_version}_${platform}_${arch}.tar.gz"

if [ -n "$base_url" ]; then
  base_url="${base_url%/}"
  log "Using custom asset base URL: ${base_url}"
elif [ "$repo" != "$default_repo" ]; then
  log "Using custom GitHub release repo: ${repo}"
fi

if [ -z "$base_url" ]; then
  base_url="https://github.com/${repo}/releases/download/${release_version}"
fi

archive_path="${tmpdir}/${archive}"
checksum_path="${archive_path}.sha256"

log "Detected: ${platform} ${arch}"
log "Downloading: ${archive}"
download "${base_url}/${archive}" "$archive_path"
download "${base_url}/${archive}.sha256" "$checksum_path"

expected_checksum="$(cat "$checksum_path")"
actual_checksum="$(sha256_file "$archive_path")"
[ "$actual_checksum" = "$expected_checksum" ] || fail "checksum verification failed for ${archive}"
log "Verified checksum"

tar -xzf "$archive_path" -C "$tmpdir" cleotic
chmod 0755 "${tmpdir}/cleotic"

if [ ! -d "$install_dir" ]; then
  mkdir -p "$install_dir" || fail "could not create install directory: ${install_dir}"
fi

if [ ! -w "$install_dir" ]; then
  fail "${install_dir} is not writable. Set CLEOTIC_INSTALL_DIR to a directory you can write to."
fi

mv "${tmpdir}/cleotic" "${install_dir}/cleotic"

log "Installed cleotic to ${install_dir}/cleotic"
if ! path_contains "$install_dir"; then
  log "Warning: ${install_dir} is not on your PATH."
  log "Add it to PATH before running cleotic."
fi
log "Run: cleotic auth login"
