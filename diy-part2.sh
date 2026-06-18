#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 临时解决Rust问题
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile

# add date in output file name
sed -i -e '/^IMG_PREFIX:=/i BUILD_DATE := $(shell date +%Y%m%d)' \
       -e '/^IMG_PREFIX:=/ s/\($(SUBTARGET)\)/\1-$(BUILD_DATE)/' include/image.mk

# set ubi to 122M
# sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0x7a40000>;/' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts

# ===============================
# Minimal additions: CudyX / xiaomaozai / 512M DTS only
# Do not remove original packages or change non-512M device logic.
# ===============================
BUILD_DEVICE="${BUILD_DEVICE:-}"

# Set hostname only. Do not change LAN IP or switch/network settings.
mkdir -p files/etc/uci-defaults
cat > files/etc/uci-defaults/90-cudyx-defaults <<'EOF_CUDYX'
#!/bin/sh
uci set system.@system[0].hostname='CudyX'
uci commit system
exit 0
EOF_CUDYX
chmod +x files/etc/uci-defaults/90-cudyx-defaults

# XiaoMaoZai LuCI badge.
mkdir -p files/www/luci-static/custom files/etc/uci-defaults
cat > files/www/luci-static/custom/xiaomaozai-badge.js <<'EOF_BADGE_JS'
(function () {
  function addBadge() {
    if (document.getElementById('xiaomaozai-badge')) return;
    var a = document.createElement('a');
    a.id = 'xiaomaozai-badge';
    a.textContent = '小猫崽';
    a.href = 'https://github.com/asrtroh-netizen/immortalwrt-mt7981-cudy-tr3000';
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    a.style.cssText = [
      'position:fixed','right:14px','bottom:14px','z-index:99999',
      'padding:6px 10px','border-radius:999px','font-size:12px',
      'line-height:1','text-decoration:none','background:rgba(0,0,0,.62)',
      'color:#fff','box-shadow:0 2px 10px rgba(0,0,0,.25)',
      'backdrop-filter:blur(6px)'
    ].join(';');
    document.body.appendChild(a);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', addBadge);
  else addBadge();
})();
EOF_BADGE_JS

cat > files/etc/uci-defaults/93-xiaomaozai-badge <<'EOF_BADGE_UCI'
#!/bin/sh
set -e
for f in /usr/share/ucode/luci/template/themes/*/header.ut /usr/lib/lua/luci/view/themes/*/header.htm; do
  [ -f "$f" ] || continue
  grep -q 'xiaomaozai-badge.js' "$f" && continue
  if grep -q '</body>' "$f"; then
    sed -i 's#</body>#<script src="/luci-static/custom/xiaomaozai-badge.js"></script></body>#' "$f"
  else
    printf '\n<script src="/luci-static/custom/xiaomaozai-badge.js"></script>\n' >> "$f"
  fi
done
exit 0
EOF_BADGE_UCI
chmod +x files/etc/uci-defaults/93-xiaomaozai-badge

# 512M DTS patch. Only run for BUILD_DEVICE=512M.
if [ "$BUILD_DEVICE" = "512M" ]; then
  echo "========== 512M DTS injection =========="
  TMP_DIR="/tmp/cudy-tr3000-512"
  rm -rf "$TMP_DIR"
  git clone --depth=1 https://github.com/zhuannn/cudy-tr3000-512 "$TMP_DIR"

  # Copy DTS if found.
  DTS_SRC="$(find "$TMP_DIR" -type f -name 'mt7981b-cudy-tr3000-512mb-v1.dts' | head -n 1)"
  if [ -n "$DTS_SRC" ]; then
    cp -f "$DTS_SRC" target/linux/mediatek/dts/mt7981b-cudy-tr3000-512mb-v1.dts
  else
    echo "ERROR: 512M DTS not found in zhuannn/cudy-tr3000-512"
    exit 1
  fi

  # Append device definition only if upstream tree does not already have it.
  if ! grep -R "cudy_tr3000-512mb-v1" -n target/linux/mediatek/image package 2>/dev/null | grep -q .; then
    MK_SRC="$(find "$TMP_DIR" -type f \( -name '*.mk' -o -name 'cudy-tr3000-512.mk' \) | head -n 1)"
    if [ -n "$MK_SRC" ]; then
      cat "$MK_SRC" >> target/linux/mediatek/image/filogic.mk
    else
      cat >> target/linux/mediatek/image/filogic.mk <<'EOF_512_DEV'

define Device/cudy_tr3000-512mb-v1
  DEVICE_VENDOR := Cudy
  DEVICE_MODEL := TR3000
  DEVICE_VARIANT := 512MB v1
  DEVICE_DTS := mt7981b-cudy-tr3000-512mb-v1
  DEVICE_DTS_DIR := ../dts
  DEVICE_PACKAGES := kmod-mt7981-firmware mt7981-wo-firmware kmod-usb3 kmod-mt_wifi
  IMAGE_SIZE := 520000k
  IMAGES := sysupgrade.bin
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += cudy_tr3000-512mb-v1
EOF_512_DEV
    fi
  fi
fi

