<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/15feaff7-49f2-4927-888f-7ac2258ba5ff" />



<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/15feaff7-49f2-4927-888f-7ac2258ba5ff" />

# Cudy TR3000 ImmortalWrt Auto Build 🐱

> 给 Cudy TR3000 准备的一套 ImmortalWrt 自动编译仓库。
> 小猫崽出品，主打一个：能编、能刷、别乱刷。😼

---

## 这是什么？

这是一个基于 GitHub Actions 的 ImmortalWrt 自动编译项目，主要用于 Cudy TR3000 v1 系列设备。

本仓库当前主要维护：

| 版本   | 状态 | 说明                   |
| ---- | -: | -------------------- |
| 256M |  ✅ | 原版基础上的改版配置           |
| 512M |  ✅ | 额外注入 512M DTS / 分区配置 |

选择 `all` 时，会自动编译：

```text
256M
512M
```

---

## 重要提醒，先看这里 ⚠️

不同 Flash 容量的固件不要混刷。

```text
256M 设备刷 256M
512M 改版设备刷 512M
```

刷错容量，轻则启动失败，重则需要救砖。

我不拦你折腾，但猫爪子已经按在警告牌上了。🐾

---

## 当前项目特点

### 1. 512M 自动注入 DTS

512M 固件会自动拉取并注入 512M 设备定义：

```text
cudy_tr3000-512mb-v1
mt7981b-cudy-tr3000-512mb-v1.dts
IMAGE_SIZE := 520000k
```

当编译 `256M` 时，不会注入 512M DTS。

也就是说：

```text
256M：走原版改版配置
512M：走 512M 专用配置
all：分别编译 256M、512M
```

---

### 2. 4G / 5G 模块驱动增强

保留原版内容的基础上，额外补充了常见 4G / 5G USB 模块所需驱动。

覆盖方向包括：

```text
QMI
MBIM
NCM
RNDIS
CDC Ethernet
USB Serial
USB Option
WWAN
QRTR
MHI / 5G 相关基础支持
```

常见模块类型：

```text
Quectel EC20 / EC25 / EG25 / EP06
Quectel RM500Q / RM520N / RM500U
Fibocom L850 / L860 / FM150 / FM160 / FM350
SIMCom 部分 4G / 5G 模块
Huawei NCM 类模块
```

是否能识别，还取决于模块本身 USB 模式、固件、接口组合和运营商卡状态。

驱动不是玄学，但 4G/5G 模块有时候挺玄。😹

---

### 3. 主题

保留原版已有主题：

```text
luci-theme-aurora
luci-app-aurora-config
```

同时保留原版已有的 Bandix 相关组件。

---

### 4. 默认系统设置

默认主机名：

```text
CudyX
```

默认 LAN IP：

```text
192.168.2.1
```

默认时区：

```text
Asia/Shanghai
```

---

## 使用方法

进入 GitHub Actions：

```text
Actions → ImmortalWrt Builder → Run workflow
```

选择设备：

```text
256M
512M
all
```

推荐：

```text
单独测试：先选 256M 或 512M
批量出包：选 all
```

`all` 只会编译：

```text
256M
512M
```

---

## 文件说明

```text
.github/workflows/openwrt-builder.yml
```

GitHub Actions 自动编译流程。

```text
diy-part1.sh
```

feeds 更新前执行。
用于保留原版 Aurora / Bandix 等内容。

```text
diy-part2.sh
```

feeds 更新后执行。
用于：

```text
512M DTS 注入
默认主机名
默认 LAN IP
小猫崽角标
4G / 5G 驱动配置补充
```

```text
config/256m.config
config/512m.config
```

不同容量设备的编译配置。

---

## 固件文件怎么选？

编译成功后，在 Artifacts 或 Releases 中下载固件。

常见文件名会包含：

```text
256m
512mb
sysupgrade
factory
```

一般升级已有系统用：

```text
sysupgrade.bin
```

首次刷机或特殊恢复场景再考虑：

```text
factory.bin
```

具体看你设备当前状态，不要盲刷。

---

## 4G / 5G 模块检查命令

刷好后 SSH 进入系统，可以用下面命令检查模块识别情况：

```sh
lsusb
dmesg | grep -Ei 'qmi|mbim|ncm|rndis|wwan|cdc|ttyUSB|option|quectel|fibocom|simcom'
ls /dev/cdc-wdm* 2>/dev/null
ip link | grep -E 'wwan|usb|enx'
```

如果是 QMI 模式，通常应该看到：

```text
/dev/cdc-wdm0
wwan0
```

如果只有：

```text
ttyUSB0
ttyUSB1
ttyUSB2
ttyUSB3
```

那可能是模块模式、接口绑定或驱动匹配问题。

---

## 致谢

感谢这些项目和作者：

```text
ImmortalWrt
P3TERX Actions-OpenWrt
padavanonly/immortalwrt-mt798x-6.6
zhuannn/cudy-tr3000-512
eamonxg/luci-theme-aurora
timsaya/luci-app-bandix
```

以及所有愿意把路由器刷到凌晨还不睡的人。

你们都很强，也都有点上头。😼

---

## 免责声明

本项目仅供学习、测试和折腾使用。

刷机有风险，操作需谨慎。

因刷错固件、断电、选错容量、手滑、猫踩键盘造成的问题，请自行承担。






