#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

set -e

echo "============================================================"
echo " DIY PART1: Add extra packages before feeds update"
echo "============================================================"

mkdir -p package

# ============================================================
# Download GitHub repo helper
# Try tar.gz first, git clone fallback
# ============================================================

download_repo() {
  local owner="$1"
  local repo="$2"
  local dir="$3"

  echo "============================================================"
  echo "Download ${owner}/${repo}"
  echo "To       ${dir}"
  echo "============================================================"

  rm -rf "$dir"
  mkdir -p "$dir"

  local ok="0"

  for branch in main master; do
    local url="https://codeload.github.com/${owner}/${repo}/tar.gz/refs/heads/${branch}"
    local tmp="/tmp/${repo}-${branch}.tar.gz"

    echo "Try: $url"

    if curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$tmp"; then
      tar -xzf "$tmp" -C "$dir" --strip-components=1
      rm -f "$tmp"
      ok="1"
      echo "OK: ${owner}/${repo} branch ${branch}"
      break
    fi

    rm -f "$tmp"
  done

  if [ "$ok" != "1" ]; then
    echo "Tarball download failed, try git clone fallback"
    rm -rf "$dir"
    git clone --depth=1 "https://github.com/${owner}/${repo}.git" "$dir"
  fi
}

# ============================================================
# Keep local luci-compat package if exists
# ============================================================

if [ -d "$GITHUB_WORKSPACE/package/luci-compat-keep" ]; then
  echo "Copy local luci-compat-keep"
  rm -rf package/luci-compat-keep
  cp -r "$GITHUB_WORKSPACE/package/luci-compat-keep" package/
fi

# ============================================================
# Clean old extra packages
# ============================================================

rm -rf package/passwall
rm -rf package/passwall-packages
rm -rf package/nikki
rm -rf package/luci-theme-aurora
rm -rf package/luci-app-aurora-config
rm -rf package/luci-theme-argon
rm -rf package/luci-app-argon-config
rm -rf package/luci-app-bandix
rm -rf package/openwrt-bandix

# ============================================================
# PassWall
# ============================================================

download_repo "Openwrt-Passwall" "openwrt-passwall" "package/passwall"
download_repo "Openwrt-Passwall" "openwrt-passwall-packages" "package/passwall-packages"

# ============================================================
# Nikki
# ============================================================

download_repo "nikkinikki-org" "OpenWrt-nikki" "package/nikki"

# ============================================================
# LuCI Themes: Aurora / Argon
# ============================================================

download_repo "eamonxg" "luci-theme-aurora" "package/luci-theme-aurora"
download_repo "eamonxg" "luci-app-aurora-config" "package/luci-app-aurora-config"

download_repo "jerrykuku" "luci-theme-argon" "package/luci-theme-argon"
download_repo "jerrykuku" "luci-app-argon-config" "package/luci-app-argon-config"

# ============================================================
# Bandix
# ============================================================

download_repo "timsaya" "luci-app-bandix" "package/luci-app-bandix"
download_repo "timsaya" "openwrt-bandix" "package/openwrt-bandix"

# ============================================================
# Remove git metadata from local packages
# ============================================================

find package -name ".git" -type d -prune -exec rm -rf {} + || true

echo "============================================================"
echo " DIY PART1 done"
echo "============================================================"
