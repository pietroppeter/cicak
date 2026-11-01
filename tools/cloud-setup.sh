#!/usr/bin/env bash
# Setup script for Claude Code cloud sessions (and any fresh Linux x64 box):
# installs Nim 2.4 with nifler, nifmake and atlas, and puts them first on PATH
# by symlinking into /usr/local/bin (this replaces an older nim there).
#
# Paste the whole file into the environment's "Setup script" field.
# Network it needs: nim-lang.org (prebuilt binaries); github.com only for the
# source-build fallback.
#
# Prebuilt route: the official linux_x64 tarball. Since the 2026-10-28 rebuild
# it ships bin/nifler and bin/nifmake next to nim and atlas. If a tarball comes
# without them, the script falls back to building the version-2-4 branch.
set -euo pipefail

NIM_VERSION="${NIM_VERSION:-2.4.0}"
PREFIX="${NIM_PREFIX:-/opt/nim}"
BIN_DIR=/usr/local/bin
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

log() { echo "[cicak-setup] $*"; }

install_prebuilt() {
  local tmp url
  tmp="$(mktemp -d)"
  url="https://nim-lang.org/download/nim-${NIM_VERSION}-linux_x64.tar.xz"
  log "downloading $url"
  curl -fsSL --retry 3 -o "$tmp/nim.tar.xz" "$url" || return 1
  curl -fsSL --retry 3 -o "$tmp/nim.sha256" "$url.sha256" || return 1
  (cd "$tmp" && echo "$(cut -d' ' -f1 nim.sha256)  nim.tar.xz" | sha256sum -c -) || return 1
  tar -xJf "$tmp/nim.tar.xz" -C "$tmp"
  for tool in nim nifler nifmake atlas; do
    [ -x "$tmp/nim-${NIM_VERSION}/bin/$tool" ] || { log "tarball has no bin/$tool"; return 1; }
  done
  $SUDO rm -rf "$PREFIX"
  $SUDO mv "$tmp/nim-${NIM_VERSION}" "$PREFIX"
  rm -rf "$tmp"
}

build_from_source() {
  log "building the version-2-4 branch from source (a few minutes)"
  $SUDO rm -rf "$PREFIX"
  $SUDO git clone -q --depth 1 -b version-2-4 https://github.com/nim-lang/Nim "$PREFIX"
  $SUDO chown -R "$(id -u):$(id -g)" "$PREFIX"
  cd "$PREFIX"
  . config/build_config.txt
  git clone -q "$nim_csourcesUrl" "$nim_csourcesDir"
  git -C "$nim_csourcesDir" checkout -q "$nim_csourcesHash"
  make -C "$nim_csourcesDir" -j"$(nproc)"
  ./bin/nim c --hints:off --skipUserCfg --skipParentCfg koch
  ./koch boot -d:release --skipUserCfg --skipParentCfg
  ./koch atlas --skipUserCfg --skipParentCfg
  rm -rf "$nim_csourcesDir"
  cd - >/dev/null
}

install_prebuilt || build_from_source

# Symlinks: nim resolves its lib/ and sibling tools (nifler, nifmake) from the
# real path of its executable, so linking is enough.
for tool in "$PREFIX"/bin/*; do
  [ -f "$tool" ] && [ -x "$tool" ] && $SUDO ln -sf "$tool" "$BIN_DIR/$(basename "$tool")"
done
hash -r

# nimib's markdown renderer loads libpcre at runtime.
if ! ldconfig -p 2>/dev/null | grep -q 'libpcre\.so\.3'; then
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq libpcre3 || log "could not install libpcre3"
fi

nim -v | head -1
for tool in nifler nifmake atlas; do
  command -v "$tool" >/dev/null || { log "missing $tool on PATH"; exit 1; }
done
log "ok: $(command -v nim) -> $(readlink -f "$(command -v nim)")"
