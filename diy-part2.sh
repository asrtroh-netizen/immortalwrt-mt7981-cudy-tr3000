#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Based on original fork. Keeps original packages and only adds:
# 1. TR3000 512M DTS/profile
# 2. Full 4G/5G modem drivers
# 3. Argon theme config option
# 4. Hostname CudyX + LAN 192.168.2.1
# 5. XiaoMaoZai LuCI corner badge
#

set -e

# Temporary Rust workaround
if [ -f feeds/packages/lang/rust/Makefile ]; then
  sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

# Add date in output file name, safer than multiline sed on GitHub web editor copies
if [ -f include/image.mk ] && ! grep -q 'BUILD_DATE := $(shell date +%Y%m%d)' include/image.mk; then
  perl -0pi -e 's/^(IMG_PREFIX:=.*)$/BUILD_DATE := \$(shell date +%Y%m%d)\n$1/m' include/image.mk
  perl -0pi -e 's/\$\(SUBTARGET\)/\$(SUBTARGET)-\$(BUILD_DATE)/g' include/image.mk
fi

# GitHub tarball download helper
download_repo() {
  local owner="$1"
  local repo="$2"
  local dir="$3"
  local branch=""
  local url=""
  local tmp=""
  local ok="0"

  echo "============================================================"
  echo "Download ${owner}/${repo}"
  echo "Target ${dir}"
  echo "============================================================"

  rm -rf "$dir"

  for branch in main master; do
    url="https://codeload.github.com/${owner}/${repo}/tar.gz/refs/heads/${branch}"
    tmp="/tmp/${owner}-${repo}-${branch}.tar.gz"
    if curl -fsSL --retry 3 --connect-timeout 20 "$url" -o "$tmp"; then
      mkdir -p "$dir"
      tar -xzf "$tmp" -C "$dir" --strip-components=1
      rm -f "$tmp"
      ok="1"
      echo "Downloaded ${owner}/${repo} branch ${branch}"
      break
    fi
    rm -f "$tmp"
  done

  if [ "$ok" != "1" ]; then
    echo "Tarball failed, try git clone"
    git clone --depth=1 "https://github.com/${owner}/${repo}.git" "$dir"
  fi
}

# Inject TR3000 512M DTS/profile only for 512M builds.
# CURRENT_DEVICE is set by workflow per build loop. DEVICE_INPUT is kept as fallback.
BUILD_DEVICE="${CURRENT_DEVICE:-${DEVICE_INPUT:-}}"
echo "========== DIY PART2 DEVICE =========="
echo "BUILD_DEVICE=${BUILD_DEVICE}"

if [ "$BUILD_DEVICE" = "512M" ] || [ "$BUILD_DEVICE" = "all" ]; then
  if [ -f target/linux/mediatek/image/filogic.mk ] && [ -d target/linux/mediatek/dts ]; then
    download_repo "zhuannn" "cudy-tr3000-512" "mod512"

    test -f mod512/openwrt-mod/cudy-tr3000-512.mk
    test -n "$(find mod512 -name '*.dts' -print -quit)"

    echo "========== MOD512 MK CHECK =========="
    grep -E "cudy_tr3000-512mb-v1|DEVICE_DTS|IMAGE_SIZE|TARGET_DEVICES" mod512/openwrt-mod/cudy-tr3000-512.mk || true

    if ! grep -q "cudy_tr3000-512mb-v1" target/linux/mediatek/image/filogic.mk; then
      cat mod512/openwrt-mod/cudy-tr3000-512.mk >> target/linux/mediatek/image/filogic.mk
    fi

    echo "========== COPY 512M DTS =========="
    find mod512 -name "*.dts" -print0 | while IFS= read -r -d '' dtsfile; do
      echo "Copy DTS: $dtsfile"
      cp -f "$dtsfile" target/linux/mediatek/dts/
    done
  fi
else
  echo "Skip 512M DTS injection for ${BUILD_DEVICE}"
fi

# Built-in defaults and LuCI badge
mkdir -p files/etc/uci-defaults
mkdir -p files/www/luci-static/custom

cat > files/etc/uci-defaults/90-cudyx-defaults <<'EOF'
#!/bin/sh

uci -q set system.@system[0].hostname='CudyX'
uci -q set system.@system[0].zonename='Asia/Shanghai'
uci -q set system.@system[0].timezone='CST-8'

uci -q set network.lan.ipaddr='192.168.2.1'
uci -q set network.lan.netmask='255.255.255.0'

uci -q commit system
uci -q commit network

exit 0
EOF
chmod +x files/etc/uci-defaults/90-cudyx-defaults

cat > files/www/luci-static/custom/xiaomaozai-badge.js <<'EOF'
(function () {
  function addBadge() {
    if (document.getElementById('xiaomaozai-build-badge')) return;

    var badge = document.createElement('a');
    badge.id = 'xiaomaozai-build-badge';
    badge.href = 'https://github.com/asrtroh-netizen/immortalwrt-mt7981-cudy-tr3000';
    badge.target = '_blank';
    badge.rel = 'noopener noreferrer';
    badge.innerText = '小猫崽';

    badge.style.position = 'fixed';
    badge.style.right = '16px';
    badge.style.bottom = '10px';
    badge.style.zIndex = '99999';
    badge.style.padding = '6px 10px';
    badge.style.borderRadius = '10px';
    badge.style.background = 'rgba(30, 30, 46, 0.72)';
    badge.style.backdropFilter = 'blur(8px)';
    badge.style.color = '#b4befe';
    badge.style.fontSize = '12px';
    badge.style.lineHeight = '1';
    badge.style.textDecoration = 'none';
    badge.style.boxShadow = '0 4px 14px rgba(0,0,0,0.25)';
    badge.style.border = '1px solid rgba(180,190,254,0.35)';
    badge.style.fontFamily = 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';

    badge.onmouseenter = function () {
      badge.style.background = 'rgba(137, 180, 250, 0.22)';
      badge.style.color = '#ffffff';
    };

    badge.onmouseleave = function () {
      badge.style.background = 'rgba(30, 30, 46, 0.72)';
      badge.style.color = '#b4befe';
    };

    document.body.appendChild(badge);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', addBadge);
  } else {
    addBadge();
  }
})();
EOF

cat > files/etc/uci-defaults/93-xiaomaozai-badge <<'EOF'
#!/bin/sh

JS='/luci-static/custom/xiaomaozai-badge.js'
TAG='<script src="/luci-static/custom/xiaomaozai-badge.js"></script>'

for f in \
  /usr/lib/lua/luci/view/themes/*/footer.htm \
  /usr/lib/lua/luci/view/themes/*/footer.ut \
  /usr/share/ucode/luci/template/themes/*/footer.ut \
  /usr/share/ucode/luci/template/themes/*/footer.htm
do
  [ -f "$f" ] || continue
  grep -q "$JS" "$f" && continue

  if grep -q '</body>' "$f"; then
    sed -i "s#</body>#$TAG\n</body>#g" "$f"
  else
    echo "$TAG" >> "$f"
  fi
done

exit 0
EOF
chmod +x files/etc/uci-defaults/93-xiaomaozai-badge

# Keep original config, only append requested additions.
cat >> .config <<'EOF'

# ============================================================
# Added by XiaoMaoZai: Argon theme
# ============================================================
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y

# ============================================================
# Added by XiaoMaoZai: Full 4G / 5G modem drivers
# QMI / MBIM / NCM / RNDIS / CDC Ethernet / serial / MHI
# ============================================================
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y

CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-wdm=y
CONFIG_PACKAGE_kmod-usb-acm=y

CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-eem=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-fibocom=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan-quectel=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-sierrawireless=y
CONFIG_PACKAGE_kmod-usb-net-kalmia=y

CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-usb-serial-wwan=y
CONFIG_PACKAGE_kmod-usb-serial-qualcomm=y
CONFIG_PACKAGE_kmod-usb-serial-sierrawireless=y
CONFIG_PACKAGE_kmod-usb-serial-ch341=y
CONFIG_PACKAGE_kmod-usb-serial-cp210x=y
CONFIG_PACKAGE_kmod-usb-serial-ftdi=y
CONFIG_PACKAGE_kmod-usb-serial-pl2303=y
CONFIG_PACKAGE_kmod-usb-serial-mos7720=y
CONFIG_PACKAGE_kmod-usb-serial-mos7840=y

CONFIG_PACKAGE_kmod-wwan=y
CONFIG_PACKAGE_kmod-mhi-bus=y
CONFIG_PACKAGE_kmod-mhi-net=y
CONFIG_PACKAGE_kmod-mhi-pci-generic=y
CONFIG_PACKAGE_kmod-mhi-wwan-ctrl=y
CONFIG_PACKAGE_kmod-mhi-wwan-mbim=y
CONFIG_PACKAGE_kmod-qrtr-mhi=y
CONFIG_PACKAGE_kmod-qrtr-tun=y

CONFIG_PACKAGE_uqmi=y
CONFIG_PACKAGE_umbim=y
CONFIG_PACKAGE_comgt=y
CONFIG_PACKAGE_comgt-ncm=y
CONFIG_PACKAGE_chat=y
CONFIG_PACKAGE_wwan=y
CONFIG_PACKAGE_minicom=y
CONFIG_PACKAGE_picocom=y
CONFIG_PACKAGE_libqmi=y
CONFIG_PACKAGE_libmbim=y

CONFIG_PACKAGE_luci-proto-qmi=y
CONFIG_PACKAGE_luci-proto-mbim=y
CONFIG_PACKAGE_luci-proto-ncm=y
EOF

make defconfig

echo "========== FINAL DEVICE CHECK =========="
grep -E 'CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000|CONFIG_TARGET_PROFILE' .config || true

echo "========== FINAL THEME CHECK =========="
grep -E 'CONFIG_PACKAGE_luci-theme-(aurora|argon)|CONFIG_PACKAGE_luci-app-(aurora|argon)-config' .config || true

echo "========== FINAL 4G/5G DRIVER CHECK =========="
grep -E 'CONFIG_PACKAGE_(kmod-usb-net-qmi-wwan|kmod-usb-net-cdc-mbim|kmod-usb-net-cdc-ncm|kmod-usb-net-rndis|kmod-usb-serial-option|kmod-wwan|kmod-mhi|kmod-qrtr|uqmi|umbim|luci-proto-qmi|luci-proto-mbim|luci-proto-ncm)=y' .config || true

echo "========== FINAL CUSTOM FILE CHECK =========="
ls -lh files/etc/uci-defaults/90-cudyx-defaults
ls -lh files/etc/uci-defaults/93-xiaomaozai-badge
ls -lh files/www/luci-static/custom/xiaomaozai-badge.js
