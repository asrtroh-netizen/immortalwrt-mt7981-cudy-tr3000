#!/bin/bash

#

# File name: diy-part2.sh

# Description: OpenWrt DIY script part 2 (After Update feeds)

#

set -e

echo "============================================================"
echo " DIY PART2: TR3000 512M Full Build"
echo " PassWall removed for stable build"
echo "============================================================"

# ===============================

# Rust workaround CI compatibility

# ===============================

if [ -f feeds/packages/lang/rust/Makefile ]; then
sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
fi

# ===============================

# Remove unstable / unwanted packages

# ===============================

rm -rf package/passwall
rm -rf package/passwall-packages
rm -rf package/passwall-packages/geoview
rm -rf package/passwall-packages/*geoview*

# ===============================

# Build date in image filename

# ===============================

if [ -f include/image.mk ] && ! grep -q 'BUILD_DATE := $(shell date +%Y%m%d)' include/image.mk; then
perl -0pi -e 's/^(IMG_PREFIX:=.*)$/BUILD_DATE := $(shell date +%Y%m%d)\n$1/m' include/image.mk
perl -0pi -e 's/$(SUBTARGET)/$(SUBTARGET)-$(BUILD_DATE)/g' include/image.mk
fi

# ===============================

# Basic path check

# ===============================

test -f target/linux/mediatek/image/filogic.mk
test -d target/linux/mediatek/dts

# ===============================

# TR3000 512MB DTS injection

# ===============================

rm -rf mod512
git clone --depth 1 https://github.com/zhuannn/cudy-tr3000-512 mod512

test -f mod512/openwrt-mod/cudy-tr3000-512.mk
test -n "$(find mod512 -name '*.dts' -print -quit)"

echo "========== MOD512 MK CHECK =========="
grep -E "cudy_tr3000-512mb-v1|DEVICE_DTS|IMAGE_SIZE|TARGET_DEVICES" mod512/openwrt-mod/cudy-tr3000-512.mk || true

grep -q "cudy_tr3000-512mb-v1" target/linux/mediatek/image/filogic.mk || 
cat mod512/openwrt-mod/cudy-tr3000-512.mk >> target/linux/mediatek/image/filogic.mk

find mod512 -name "*.dts" -exec cp -f {} target/linux/mediatek/dts/ ;

grep -q "cudy_tr3000-512mb-v1" target/linux/mediatek/image/filogic.mk
ls target/linux/mediatek/dts/ | grep -q "tr3000.*512"

# ===============================

# Built-in files directories

# ===============================

mkdir -p files/etc/uci-defaults
mkdir -p files/etc/init.d
mkdir -p files/etc/vohive
mkdir -p files/usr/bin
mkdir -p files/www/luci-static/custom

# ===============================

# Default system settings

# ===============================

cat > files/etc/uci-defaults/90-custom-defaults <<'EOF'
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

chmod +x files/etc/uci-defaults/90-custom-defaults

# ===============================

# USB / HDD automount default

# ===============================

cat > files/etc/uci-defaults/91-automount <<'EOF'
#!/bin/sh

uci -q set fstab.@global[0].anon_swap='0'
uci -q set fstab.@global[0].anon_mount='1'
uci -q set fstab.@global[0].auto_swap='0'
uci -q set fstab.@global[0].auto_mount='1'
uci -q set fstab.@global[0].delay_root='5'
uci -q set fstab.@global[0].check_fs='0'
uci -q commit fstab

exit 0
EOF

chmod +x files/etc/uci-defaults/91-automount

# ===============================

# VoHive binary built-in

# TR3000 MT7981 is arm64

# ===============================

VOHIVE_VERSION="v1.3.5"
VOHIVE_URL="https://github.com/iniwex5/vohive-release/releases/download/${VOHIVE_VERSION}/vohive_${VOHIVE_VERSION}_linux_arm64"

echo "========== DOWNLOAD VOHIVE =========="
curl -L --retry 3 --connect-timeout 20 -o files/usr/bin/vohive "$VOHIVE_URL"
chmod +x files/usr/bin/vohive

cat > files/etc/vohive/config.yaml <<'EOF'
server:
port: 7575
debug: false

web:
username: admin
password: admin123
EOF

cat > files/etc/init.d/vohive <<'EOF'
#!/bin/sh /etc/rc.common

START=99
STOP=10

start() {
killall vohive 2>/dev/null
nohup /usr/bin/vohive -c /etc/vohive/config.yaml >/tmp/vohive.log 2>&1 &
}

stop() {
killall vohive 2>/dev/null
}
EOF

chmod +x files/etc/init.d/vohive

cat > files/etc/uci-defaults/92-vohive <<'EOF'
#!/bin/sh

/etc/init.d/vohive enable
/etc/init.d/vohive restart

exit 0
EOF

chmod +x files/etc/uci-defaults/92-vohive

# ===============================

# LuCI custom corner badge

# ===============================

cat > files/www/luci-static/custom/halox-badge.js <<'EOF'
(function () {
function addBadge() {
if (document.getElementById('halox-build-badge')) return;

```
var badge = document.createElement('a');
badge.id = 'halox-build-badge';
badge.href = 'https://halox.pages.dev/';
badge.target = '_blank';
badge.rel = 'noopener noreferrer';
badge.innerText = '编译自小猫崽 · HaloX';

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
```

}

if (document.readyState === 'loading') {
document.addEventListener('DOMContentLoaded', addBadge);
} else {
addBadge();
}
})();
EOF

cat > files/etc/uci-defaults/93-halox-badge <<'EOF'
#!/bin/sh

JS='/luci-static/custom/halox-badge.js'
TAG='<script src="/luci-static/custom/halox-badge.js"></script>'

for f in 
/usr/lib/lua/luci/view/themes/*/footer.htm 
/usr/lib/lua/luci/view/themes/*/footer.ut 
/usr/share/ucode/luci/template/themes/*/footer.ut 
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

chmod +x files/etc/uci-defaults/93-halox-badge

# ===============================

# Remove PassWall related configs from previous 512m.config

# ===============================

sed -i '/CONFIG_PACKAGE_.*passwall/d' .config || true
sed -i '/CONFIG_PACKAGE_.*PassWall/d' .config || true
sed -i '/CONFIG_PACKAGE_geoview/d' .config || true
sed -i '/CONFIG_PACKAGE_luci-app-geoview/d' .config || true
sed -i '/CONFIG_PACKAGE_xray-core/d' .config || true
sed -i '/CONFIG_PACKAGE_xray-plugin/d' .config || true
sed -i '/CONFIG_PACKAGE_v2ray-core/d' .config || true
sed -i '/CONFIG_PACKAGE_v2ray-plugin/d' .config || true
sed -i '/CONFIG_PACKAGE_sing-box/d' .config || true
sed -i '/CONFIG_PACKAGE_trojan-plus/d' .config || true
sed -i '/CONFIG_PACKAGE_shadowsocks/d' .config || true
sed -i '/CONFIG_PACKAGE_shadowsocksr/d' .config || true
sed -i '/CONFIG_PACKAGE_naiveproxy/d' .config || true
sed -i '/CONFIG_PACKAGE_hysteria/d' .config || true
sed -i '/CONFIG_PACKAGE_tuic-client/d' .config || true
sed -i '/CONFIG_PACKAGE_chinadns-ng/d' .config || true
sed -i '/CONFIG_PACKAGE_dns2socks/d' .config || true
sed -i '/CONFIG_PACKAGE_haproxy/d' .config || true
sed -i '/CONFIG_PACKAGE_ipt2socks/d' .config || true
sed -i '/CONFIG_PACKAGE_microsocks/d' .config || true
sed -i '/CONFIG_PACKAGE_simple-obfs/d' .config || true

cat >> .config <<'EOF'

# ============================================================

# Disable PassWall and unstable packages

# ============================================================

# CONFIG_PACKAGE_luci-app-passwall is not set

# CONFIG_PACKAGE_luci-i18n-passwall-zh-cn is not set

# CONFIG_PACKAGE_geoview is not set

# CONFIG_PACKAGE_luci-app-geoview is not set

# CONFIG_PACKAGE_xray-core is not set

# CONFIG_PACKAGE_xray-plugin is not set

# CONFIG_PACKAGE_v2ray-core is not set

# CONFIG_PACKAGE_v2ray-plugin is not set

# CONFIG_PACKAGE_sing-box is not set

# CONFIG_PACKAGE_trojan-plus is not set

# CONFIG_PACKAGE_naiveproxy is not set

# CONFIG_PACKAGE_hysteria is not set

# CONFIG_PACKAGE_tuic-client is not set

# ============================================================

# 4G / LTE / USB modem full drivers

# ============================================================

CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y

CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y

CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-huawei-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-sierrawireless=y
CONFIG_PACKAGE_kmod-usb-net-kalmia=y

CONFIG_PACKAGE_kmod-usb-wdm=y
CONFIG_PACKAGE_kmod-usb-acm=y

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

CONFIG_PACKAGE_uqmi=y
CONFIG_PACKAGE_umbim=y
CONFIG_PACKAGE_comgt=y
CONFIG_PACKAGE_comgt-ncm=y
CONFIG_PACKAGE_chat=y
CONFIG_PACKAGE_wwan=y
CONFIG_PACKAGE_minicom=y
CONFIG_PACKAGE_picocom=y

CONFIG_PACKAGE_luci-proto-qmi=y
CONFIG_PACKAGE_luci-proto-mbim=y

# ============================================================

# Nikki Chinese

# ============================================================

CONFIG_PACKAGE_nikki=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_luci-i18n-nikki-zh-cn=y

# ============================================================

# LuCI themes

# ============================================================

CONFIG_PACKAGE_luci-theme-aurora=y
CONFIG_PACKAGE_luci-app-aurora-config=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y

# ============================================================

# Bandix

# ============================================================

CONFIG_PACKAGE_luci-app-bandix=y
CONFIG_PACKAGE_bandix=y

# ============================================================

# USB / HDD automount

# ============================================================

CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-hd-idle=y
CONFIG_PACKAGE_hd-idle=y

CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y

CONFIG_PACKAGE_kmod-scsi-core=y
CONFIG_PACKAGE_kmod-scsi-generic=y

CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-fs-ntfs3=y

CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_f2fs-tools=y
CONFIG_PACKAGE_exfat-mkfs=y
CONFIG_PACKAGE_exfat-fsck=y
CONFIG_PACKAGE_ntfs-3g=y
CONFIG_PACKAGE_ntfs-3g-utils=y
CONFIG_PACKAGE_parted=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_blkid=y

CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y

# ============================================================

# Useful LuCI tools

# ============================================================

CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-filebrowser=y
CONFIG_PACKAGE_luci-app-commands=y

EOF

make defconfig

grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000-512mb-v1=y' .config
grep -q '^CONFIG_TARGET_PROFILE="DEVICE_cudy_tr3000-512mb-v1"' .config
! grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000-v1-256mb=y' .config

grep -q '^CONFIG_PACKAGE_kmod-usb-net=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-wdm=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-serial=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-serial-option=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-serial-wwan=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-net-rndis=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y' .config
grep -q '^CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y' .config
grep -q '^CONFIG_PACKAGE_luci-proto-qmi=y' .config
grep -q '^CONFIG_PACKAGE_luci-proto-mbim=y' .config

echo "========== FINAL TARGET CHECK =========="
grep -E 'CONFIG_TARGET_mediatek_filogic_DEVICE_cudy_tr3000|CONFIG_TARGET_PROFILE' .config

echo "========== FINAL 4G DRIVER CHECK =========="
grep -E 'CONFIG_PACKAGE_(kmod-usb-net|kmod-usb-net-qmi-wwan|kmod-usb-wdm|kmod-usb-serial|kmod-usb-serial-option|kmod-usb-serial-wwan|kmod-usb-net-rndis|kmod-usb-net-cdc-ether|kmod-usb-net-cdc-mbim|kmod-usb-net-cdc-ncm|uqmi|umbim|wwan|usb-modeswitch|luci-proto-qmi|luci-proto-mbim)=y' .config || true

echo "========== FINAL APP CHECK =========="
grep -E 'CONFIG_PACKAGE_(nikki|luci-app-nikki|luci-i18n-nikki-zh-cn|luci-theme-aurora|luci-app-aurora-config|luci-theme-argon|luci-app-argon-config|luci-app-bandix|bandix|block-mount|luci-app-diskman|luci-app-hd-idle|luci-app-ttyd|luci-app-filebrowser|luci-app-commands)=y' .config || true

echo "========== FINAL CUSTOM FILE CHECK =========="
ls -lh files/usr/bin/vohive
ls -lh files/etc/init.d/vohive
ls -lh files/etc/vohive/config.yaml
ls -lh files/www/luci-static/custom/halox-badge.js
ls -lh files/etc/uci-defaults/90-custom-defaults
ls -lh files/etc/uci-defaults/91-automount
ls -lh files/etc/uci-defaults/92-vohive
ls -lh files/etc/uci-defaults/93-halox-badge

echo "OK: TR3000 512MB stable build config + DTS + 4G drivers + Nikki + VoHive + HaloX badge enabled."

