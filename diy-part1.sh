#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#
# Based on original fork, only adds Argon theme source.
#

set -e

# Copy custom local packages into OpenWrt tree so they are available during build
if [ -d "$GITHUB_WORKSPACE/package/luci-compat-keep" ]; then
  mkdir -p package
  rm -rf package/luci-compat-keep
  cp -r "$GITHUB_WORKSPACE/package/luci-compat-keep" package/
fi

clone_repo() {
  local repo="$1"
  local dir="$2"
  local owner_name="${repo#https://github.com/}"
  owner_name="${owner_name%.git}"
  local owner="${owner_name%%/*}"
  local name="${owner_name##*/}"
  local branch=""
  local url=""
  local tmp=""
  local ok="0"

  echo "============================================================"
  echo "Download ${owner_name}"
  echo "Target ${dir}"
  echo "============================================================"

  rm -rf "$dir"

  for branch in main master; do
    url="https://codeload.github.com/${owner}/${name}/tar.gz/refs/heads/${branch}"
    tmp="/tmp/${owner}-${name}-${branch}.tar.gz"
    if curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$tmp"; then
      mkdir -p "$dir"
      tar -xzf "$tmp" -C "$dir" --strip-components=1
      rm -f "$tmp"
      ok="1"
      echo "Downloaded ${owner_name} branch ${branch}"
      break
    fi
    rm -f "$tmp"
  done

  if [ "$ok" != "1" ]; then
    echo "Tarball failed, try git clone: $repo"
    git clone --depth=1 "$repo" "$dir"
  fi
}

# Keep original fork packages
clone_repo "https://github.com/eamonxg/luci-theme-aurora" package/luci-theme-aurora
clone_repo "https://github.com/eamonxg/luci-app-aurora-config" package/luci-app-aurora-config
clone_repo "https://github.com/timsaya/luci-app-bandix" package/luci-app-bandix
clone_repo "https://github.com/timsaya/openwrt-bandix" package/openwrt-bandix

# Add only Argon theme
clone_repo "https://github.com/jerrykuku/luci-theme-argon" package/luci-theme-argon
clone_repo "https://github.com/jerrykuku/luci-app-argon-config" package/luci-app-argon-config

find package -name ".git" -type d -prune -exec rm -rf {} + || true
