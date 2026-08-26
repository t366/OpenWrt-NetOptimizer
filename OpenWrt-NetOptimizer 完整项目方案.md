# OpenWrt-NetOptimizer 完整项目方案


## 一、项目概述

### 1.1 项目名称

**OpenWrt-NetOptimizer** —— OpenWrt 一体化网络监控与智能链路优化系统

### 1.2 项目定位

将流量监控（nlbwmon）、域名/IP/ASN/地理位置分析、策略路由（PBR）、自适应带宽管理（SQM + sqm-autorate）、高性能透明代理（dae/daed）等模块深度融合，构建一个**开箱即用、高度集成**的 OpenWrt 定制固件与软件包体系。

### 1.3 技术背景

OpenWrt 25.12.0 已于 2026 年 3 月 5 日正式发布，**包管理器从 opkg 切换为 apk（Alpine Package Keeper）** 。当前最新稳定版本为 25.12.5（2026 年 7 月 1 日）。OpenWrt 25.12 内核版本升级到 6.12.71，为 eBPF 提供了更好的支持。

版本支持策略：
- **主攻 OpenWrt 25.12+**：使用 `apk`，输出 `.apk` 包
- **OpenWrt 24.10 将于 2026 年 9 月 EOL**（官方已停止后续安全支持），不再单独维护 `.ipk` 打包线；EOL 前如有需要仅提供社区兼容包，不做长期支持

### 1.4 项目目标

| 目标 | 描述 |
|------|------|
| **一体化** | 将监控、分析、路由优化、带宽管理、代理分流整合为统一系统 |
| **可视化** | 提供 LuCI 统一管理界面 + Neko Master 深度分析面板 |
| **智能化** | 基于实时流量数据自动调整路由策略和带宽分配 |
| **高性能** | 基于 eBPF 技术实现内核级流量处理，直连流量几乎零开销 |
| **可打包** | 支持编译为 `.ipk` / `.apk` 包，便于分发和安装 |


## 二、系统架构

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OpenWrt-NetOptimizer 系统架构                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     用户界面层                                       │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │   │
│  │  │ nlbwmon  │ │   PBR    │ │   SQM    │ │  daede   │ │Neko Mast │ │   │
│  │  │ 流量统计 │ │ 策略路由 │ │ 带宽管理 │ │ 透明代理 │ │ 分析面板 │ │   │
│  │  │ LuCI界面 │ │ LuCI界面 │ │ LuCI界面 │ │ LuCI界面 │ │ (独立)   │ │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────┼─────────────────────────────────────┐ │
│  │         核心服务层              │                                     │ │
│  │  ┌──────────────┐ ┌────────────┴───────────┐ ┌──────────────────┐  │ │
│  │  │  dnsmasq-full │ │   pbr (策略路由引擎)    │ │  sqm-autorate   │  │ │
│  │  │ (域名解析关联) │ │   + MWAN3 (多线负载)   │ │ (自适应带宽调整) │  │ │
│  │  └──────────────┘ └────────────────────────┘ └──────────────────┘  │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │              dae/daed (eBPF 透明代理内核)                    │  │ │
│  │  │    流量在内核态分流，直连流量几乎零开销              │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────┼─────────────────────────────────────┐ │
│  │         数据层                  │                                     │ │
│  │  ┌──────────────┐ ┌────────────┴───────────┐ ┌──────────────────┐  │ │
│  │  │  nlbwmon     │ │  v2ray-geoip/geosite   │ │  Neko Master     │  │ │
│  │  │ (流量采集)    │ │  (IP地理位置/ASN数据)   │ │  Agent (采集代理)│  │ │
│  │  └──────────────┘ └────────────────────────┘ └──────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│  ┌─────────────────────────────────┼─────────────────────────────────────┐ │
│  │         内核层                  │                                     │ │
│  │  ┌──────────────────────────────────────────────────────────────┐  │ │
│  │  │    Linux 内核 6.12.71+ eBPF + BTF 支持   │  │ │
│  │  └──────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **架构注记**：Neko Master 为可选扩展组件，其数据源是 Clash/Mihomo/Surge 网关 API，
> 不读取 nlbwmon 统计、也不对接 dae/daed（详见 3.2.6）。默认部署路径不包含它。


## 三、核心模块详解

### 3.1 模块清单与版本要求

| 模块 | 组件 | 源码地址 | OpenWrt 25.12 包名 | 24.10 包名 |
|------|------|---------|-------------------|-----------|
| **流量采集** | nlbwmon + LuCI | 官方源 | `nlbwmon`, `luci-app-nlbwmon` | 同左 |
| **域名解析** | dnsmasq-full | 官方源 | `dnsmasq-full` | 同左 |
| **地理位置** | v2ray-geoip/geosite | 官方源 | `v2ray-geoip`, `v2ray-geosite` | 同左 |
| **策略路由** | pbr + luci-app-pbr | **官方源**（上游 [stangri/pbr](https://github.com/stangri/pbr)） | `pbr`, `luci-app-pbr`（25.12.5 为 1.2.2-r20，无需第三方下载） | 同左 |
| **带宽管理** | sqm-scripts + LuCI | 官方源 | `sqm-scripts`, `luci-app-sqm` | 同左 |
| **自适应带宽** | sqm-autorate | [sqm-autorate/sqm-autorate](https://github.com/sqm-autorate/sqm-autorate)（活跃，Lua 版 v0.6.1；`tievolu` 旧仓库为停更 Perl 原型，勿用） | 官方源无此包，从上游 Release 安装 `sqm-autorate-0.6.1-r1.apk` + `lua-vstruct-2.1.1-r1.apk` | 同左（`.ipk`） |
| **透明代理** | dae + daed + luci-app-daede | [kenzok8/openwrt-daede](https://github.com/kenzok8/openwrt-daede) | `dae`, `daed`, `luci-app-daede`（需内核 BTF，见 3.2.5） | 同左 |
| **分析面板（可选）** | Neko Master Agent | [foru17/neko-master](https://github.com/foru17/neko-master) | Docker 独立部署；**数据源仅限 Clash/Mihomo/Surge 网关 API，不读取 nlbwmon/dae 数据**（见 3.2.6） | 同左 |

### 3.2 各模块详细说明

#### 3.2.1 流量采集与域名关联（nlbwmon + dnsmasq-full）

- **nlbwmon**：按设备/IP 统计流量，支持日/周/月趋势
- **dnsmasq-full**：DNS 解析时将域名与 IP 关联，供 nlbwmon 和 PBR 使用
- 数据持久化需配置 `/etc/sysctl.conf` 增大 netlink 缓冲区

#### 3.2.2 地理位置与 ASN 数据（v2ray-geoip/geosite）

- **v2ray-geoip**：IP 地址 → 国家/地区 + ASN 映射
- **v2ray-geosite**：域名分类（如 `geosite:netflix`、`geosite:google`）
- 为 PBR 和 dae 提供基于地理位置/ASN 的分流数据源

#### 3.2.3 策略路由引擎（pbr + luci-app-pbr）

- 基于 IP、MAC、端口、协议或域名的灵活路由框架
- 支持 WAN、OpenVPN、WireGuard 和隧道接口
- 与 dnsmasq、unbound、smartdns 集成
- 提供解析器健康检查和基于规则的回滚机制
- LuCI 界面提供直观的策略表管理
- **已收入官方 openwrt/packages 源**（25.12.5 为 `pbr-1.2.2-r20`），无需第三方仓库；仅当需要比官方源更新的版本时才参考上游 [stangri/pbr](https://github.com/stangri/pbr) Releases
- 注意：pbr 定位即 mwan3 的轻量替代，两者同时启用会争抢 `ip rule`/nft 规则，**必须二选一**

#### 3.2.4 自适应带宽管理（SQM + sqm-autorate）

- **SQM**：基于 CAKE 算法的智能队列管理，解决 Bufferbloat
- **sqm-autorate**：Lua 守护服务（procd 托管，v0.6.1），通过测量流量负载和单向延迟（OWD）主动管理 CAKE 带宽设置
  - 注意：早期 `tievolu/sqm-autorate` 是已停更的 Perl 原型（2022 年起无更新），**请勿使用**；活跃项目为 `sqm-autorate/sqm-autorate`
- 主要适用于 DOCSIS/有线电视和 LTE/无线等带宽波动网络
- 配置文件为 `/etc/config/sqm-autorate`（UCI 格式），包含下载/上传的最低与最高带宽、延迟反射器列表等参数

#### 3.2.5 高性能透明代理（dae/daed）

- **dae**：基于 eBPF 的高性能透明代理内核，流量在内核态分流
- **daed**：dae 的带 Web 面板发行版
- **luci-app-daede**：统一管理界面，同一套 UCI 配置同时适配 dae 和 daed
- 性能优化：PGO（Profile-Guided Optimization）、Go 1.26 + SIMD
- 架构覆盖：x86_64 / i386 / aarch64（a53/a72/generic）/ armv7（a7/a9）
- **重要**：dae/daed 使用 CO-RE eBPF，**运行时**必须存在 `/sys/kernel/btf/vmlinux`。
  官方 OpenWrt 固件及官方 ImageBuilder 镜像默认**未开启** BTF，daed 会直接启动失败；
  满足方式见第四阶段「BTF 运行时要求」

#### 3.2.6 流量分析面板（Neko Master，可选）

> **重要定位说明**：Neko Master 的数据源是 **Clash/Mihomo/Surge 网关 API**
> （Mihomo/Clash 走 WebSocket，Surge v5+ 走 HTTP 轮询）。
> 它**不读取 nlbwmon 统计数据，也不支持 dae/daed**——后两者不提供 Clash 兼容 API。
> 因此本项目将其定位为**可选的深度分析扩展**，而非默认面板：

- **默认路径（推荐）**：dae/daed + nlbwmon + LuCI 各模块页面，覆盖日常监控需求，无需 Neko Master
- **扩展路径**：需要域名级实时分析与可视化时，额外部署 mihomo（或 OpenClash）作为可选代理内核并接入本面板
- 实时监控：WebSocket 实时采集，毫秒级延迟
- 域名分析：查看流量、关联 IP、连接数
- IP 分析：ASN、地理位置、关联域名
- 代理统计：各代理节点的流量分布和连接数
- Agent 模式：在 OpenWrt 上部署采集代理，上报至中心化面板
- 支持多后端同时监控


## 四、开发计划

### 4.1 阶段划分与时间线

```
阶段                      Week 1-2  Week 3-5  Week 5-6  Week 6-8  Week 8-9  Week 9-11  Week 11-12
─────────────────────────────────────────────────────────────────────────────────────────────────
一、环境与基础设施        ████████
二、核心组件集成                   ████████████
三、带宽管理集成                             ████████
四、透明代理集成                                       ████████████
五、分析面板集成                                                 ████████
六、固件构建与测试                                                           ████████████
七、文档与发布                                                                           ████████
```

### 4.2 各阶段详细任务

#### 第一阶段：环境与基础设施（第 1-2 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 搭建 Ubuntu 22.04 编译环境 | 编译依赖安装完成 | `make defconfig` 成功 |
| 克隆 OpenWrt 25.12 源码 | 源码目录就绪 | `git checkout v25.12.5` |
| 配置内核 eBPF/BTF 选项 | `.config` 文件 | `CONFIG_DEBUG_INFO_BTF=y` |
| 添加第三方 feeds | `feeds.conf.default` | kenzok8（daede）源可访问；pbr 已在官方源，无需添加 |
| 验证基础固件编译 | 基础固件 `.bin` | 可在测试设备启动 |

**内核配置关键选项**：
```
CONFIG_KERNEL_DEBUG_KERNEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
```

#### 第二阶段：核心组件集成（第 3-5 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 集成 nlbwmon + luci-app-nlbwmon | 流量统计可用 | 可查看设备流量 |
| 集成 dnsmasq-full | 域名关联可用 | nlbwmon 显示域名 |
| 集成 v2ray-geoip/geosite | 地理位置数据就绪 | GeoIP 数据可查询 |
| 集成 pbr + luci-app-pbr | 策略路由可用 | 策略可下发并生效 |
| 集成 mwan3（可选） | 多线负载可用 | 多 WAN 可负载均衡；**与 pbr 二选一，不可同时启用** |
| 集成 sqm-autorate（上游 Release apk） | 自适应带宽可用 | `apk add` 安装成功 |

**PBR 包获取**：**无需任何第三方下载**。`pbr` 与 `luci-app-pbr` 已进入官方源
（25.12.5 中为 `pbr-1.2.2-r20.apk` / `luci-app-pbr-1.2.2-r20.apk`），在 Makefile 中
直接声明依赖即可。上游 [stangri/pbr](https://github.com/stangri/pbr) 仅作版本跟进参考。

#### 第三阶段：带宽管理集成（第 5-6 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 集成 sqm-scripts + luci-app-sqm | SQM 配置界面 | CAKE 队列生效 |
| 集成 kmod-sched-cake | CAKE 算法支持 | `tc qdisc` 显示 cake |
| 部署 sqm-autorate | 自适应带宽 | 带宽随负载自动调整 |

**sqm-autorate 部署步骤**（Lua 版 v0.6.1，来源 `sqm-autorate/sqm-autorate` Releases）：
```bash
# 25.12+（apk）：从上游 Release 安装两个 apk 包
apk add --allow-untrusted \
  https://github.com/sqm-autorate/sqm-autorate/releases/download/v0.6.1/lua-vstruct-2.1.1-r1.apk \
  https://github.com/sqm-autorate/sqm-autorate/releases/download/v0.6.1/sqm-autorate-0.6.1-r1.apk

# 24.10（opkg）：安装同名 .ipk
opkg install lua-vstruct_2.1.1-1_all.ipk sqm-autorate_0.6.1-1_all.ipk

# 编辑 /etc/config/sqm-autorate 设置带宽参数后启用服务
/etc/init.d/sqm-autorate enable && /etc/init.d/sqm-autorate start
```
> 注意：官方 OpenWrt 源不含此包；上游 setup 脚本按 opkg 时代编写，25.12 上建议直接用上面的 apk 安装方式。

#### 第四阶段：透明代理集成（第 6-8 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 集成 dae 内核 | eBPF 代理可用 | 代理流量正常转发 |
| 集成 daed Web 面板 | Web 管理界面 | 面板可访问 |
| 集成 luci-app-daede | LuCI 统一管理 | 同一配置管理双后端 |
| 配置代理规则 | 默认分流策略 | 基于 GeoIP/GeoSite 分流 |

**dae/daed 安装方式**：
```bash
# 一键安装脚本（自动检测内核 BTF，缺失时拉取匹配的 vmlinux-btf 包）
wget -O - https://raw.githubusercontent.com/kenzok8/openwrt-daede/refs/heads/main/scripts/install.sh | ash
```

**BTF 运行时要求（关键前提）**：dae/daed 运行时必须存在 `/sys/kernel/btf/vmlinux`，
官方 OpenWrt 固件与官方 ImageBuilder 镜像默认未开启，三条满足路线任选其一：

1. **SDK 自编内核（本项目默认路线）**：按第一阶段配置开启 `CONFIG_DEBUG_INFO_BTF` 后出完整固件
2. **ImmortalWrt 25.12 内核默认启用 BTF**：可用 [kenzok8/imagebuilder](https://github.com/kenzok8/imagebuilder) 在线生成固件
3. **补装 BTF 包**：在已有官方固件上安装与内核版本严格匹配的 [kenzok8/vmlinux-btf](https://github.com/kenzok8/vmlinux-btf) 包

**固件支持**：不要使用官方 `openwrt/imagebuilder` 构建 含 dae/daed 的固件（内核无 BTF），详见 5.4 节。

#### 第五阶段：分析面板集成（第 8-9 周，可选）

> **前提**：Neko Master 需要 Clash/Mihomo/Surge 数据源。若采用本路线，需先部署 mihomo
> （或 OpenClash）作为可选代理内核；**仅使用 dae/daed 时本阶段整体跳过**（见 3.2.6）。

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 部署 Neko Master 面板 | Docker 容器运行 | 面板可访问 |
| 部署 Neko Master Agent | OpenWrt 采集代理 | 数据上报成功 |
| 配置 GeoIP 数据库 | MMDB 文件就绪 | IP 地理位置显示 |

**Neko Master 部署**（Docker Compose）：
```yaml
services:
  neko-master:
    image: foru17/neko-master:latest
    container_name: neko-master
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
      - ./geoip:/app/data/geoip:ro
    environment:
      - NODE_ENV=production
      - DB_PATH=/app/data/stats.db
      - COOKIE_SECRET=${COOKIE_SECRET}
```

#### 第六阶段：固件构建与集成测试（第 9-11 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| ImageBuilder 固件构建 | 完整固件 `.bin` | 所有组件预集成 |
| 功能集成测试 | 测试报告 | 所有功能正常 |
| 性能基准测试 | 性能数据 | 转发性能达标 |
| 多架构构建 | x86_64/arm64 固件 | 各架构可用 |

#### 第七阶段：文档与发布（第 11-12 周）

| 任务 | 产出 | 验收标准 |
|------|------|---------|
| 用户手册 | Markdown/PDF | 完整可读 |
| 配置指南 | 示例配置 | 覆盖所有模块 |
| GitHub Releases | 固件 + 包文件 | 可下载 |
| 论坛发布帖 | 社区公告 | 获得反馈 |


## 五、编译与打包

### 5.1 包格式说明

| OpenWrt 版本 | 包管理器 | 包格式 | 配置文件路径 |
|-------------|---------|--------|-------------|
| 24.10 及更早 | opkg | `.ipk` | `/etc/opkg/distfeeds.conf` |
| 25.12 及更新 | apk | `.apk` | `/etc/apk/repositories.d/distfeeds.list` |

### 5.2 Makefile 模板

```makefile
include $(TOPDIR)/rules.mk

PKG_NAME:=openwrt-netoptimizer
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/openwrt-netoptimizer
  SECTION:=net
  CATEGORY:=Network
  TITLE:=OpenWrt Network Optimizer Suite
  DEPENDS:=+nlbwmon +dnsmasq-full +luci-app-nlbwmon \
           +v2ray-geoip +v2ray-geosite \
           +pbr +luci-app-pbr \
           +sqm-scripts +luci-app-sqm +kmod-sched-cake \
           +dae +daed +luci-app-daede \
           +kmod-sched-bpf +kmod-veth +kmod-xdp-sockets-diag \
           +kmod-nft-tproxy
  URL:=https://github.com/your-org/openwrt-netoptimizer
endef

define Package/openwrt-netoptimizer/description
  An integrated network monitoring and intelligent link optimization system.
  Includes: nlbwmon, dnsmasq-full, PBR, SQM + sqm-autorate, dae/daed.
endef

define Package/openwrt-netoptimizer/install
    $(INSTALL_DIR) $(1)/etc/config
    $(INSTALL_DATA) ./files/etc/config/nlbwmon $(1)/etc/config/
    $(INSTALL_DATA) ./files/etc/config/pbr $(1)/etc/config/
    $(INSTALL_DATA) ./files/etc/config/sqm $(1)/etc/config/
    $(INSTALL_DIR) $(1)/etc/init.d
    $(INSTALL_BIN) ./files/etc/init.d/sqm-autorate $(1)/etc/init.d/
endef

$(eval $(call BuildPackage,openwrt-netoptimizer))
```

> **依赖说明**：
> - `dnsmasq-full` 与固件默认的 `dnsmasq` 冲突：构建固件时需在 PACKAGES 中写 `-dnsmasq dnsmasq-full`
>   显式替换（见 5.4）；在已有系统上单独安装本包时需先移除 `dnsmasq`
> - `sqm-autorate` 不在官方源，**不纳入 DEPENDS**（否则 SDK 构建因缺包失败）；
>   由 `scripts/install.sh` 从上游 Release 安装，后续自托管 feed 后可加入
> - `kmod-sched-bpf`、`kmod-veth`、`kmod-xdp-sockets-diag`、`kmod-nft-tproxy` 为 dae 所必需的内核模块；
>   目标内核还必须开启 BTF 等选项（见第一阶段），否则 dae 无法运行
> - 未包含 `mwan3`：与 pbr 冲突，二选一

### 5.3 使用 SDK 编译

```bash
# 下载对应架构的 SDK（25.12 起为 zstd 压缩）
wget https://downloads.openwrt.org/releases/25.12.5/targets/x86/64/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
tar --zstd -xf openwrt-sdk-*.tar.zst
cd openwrt-sdk-*

# 放置组件源码
cp -r /path/to/openwrt-netoptimizer package/

# 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 配置并编译
make menuconfig  # 选中 openwrt-netoptimizer 为 <M>
make package/openwrt-netoptimizer/compile V=s
```

### 5.4 固件构建路线

> **警告**：官方 `openwrt/imagebuilder:25.12.5-*` Docker 镜像的内核**未开启 BTF**，
> 用其打出的固件无法运行 dae/daed。不要把 `vmlinux-btf` 写进 PACKAGES
> （该包不在 feed 中，ImageBuilder 也无法自行编译）。

| 路线 | 适用场景 | 说明 |
|------|---------|------|
| **A. SDK 全量编译（默认）** | 正式发布固件 | 使用第一阶段开启 BTF 的 `.config` 直接编译完整固件，所有组件预集成，BTF 有保障 |
| **B. kenzok8/imagebuilder 在线生成** | 快速测试 | 基于 ImmortalWrt 25.12（内核默认 BTF），GitHub Actions 生成，默认内置 `luci-app-daede` |
| C. 官方 ImageBuilder | 仅监控类固件（**不含 dae/daed**） | `docker pull openwrt/imagebuilder:25.12.5-x86-64` 后 `make image` |

PACKAGES 参考清单（路线 A/C 通用）：

```bash
PACKAGES=" \
  -dnsmasq dnsmasq-full \
  nlbwmon luci-app-nlbwmon \
  pbr luci-app-pbr \
  sqm-scripts luci-app-sqm kmod-sched-cake \
  dae daed luci-app-daede \
  kmod-sched-bpf kmod-veth kmod-xdp-sockets-diag \
  v2ray-geoip v2ray-geosite \
  luci luci-ssl \
"
```

清单要点：
- `-dnsmasq dnsmasq-full`：先移除默认 dnsmasq 再装 full 版，避免冲突
- **不再包含 `mwan3` / `luci-app-mwan3`**：pbr 即 mwan3 的轻量替代，两者同管 `ip rule`/nft 会冲突，二选一
- 若走路线 C（无 dae），删除 `dae daed luci-app-daede kmod-sched-bpf kmod-veth kmod-xdp-sockets-diag`

### 5.5 GitHub Actions 自动化编译

```yaml
name: Build OpenWrt Packages

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [x86_64, aarch64_generic, armv7]
    steps:
      - uses: actions/checkout@v4
      
      - name: Build with SDK
        uses: openwrt/gh-action-sdk@main
        env:
          ARCH: ${{ matrix.arch }}
          FEEDNAME: netoptimizer
          PACKAGES: openwrt-netoptimizer
          
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: packages-${{ matrix.arch }}
          path: bin/packages/${{ matrix.arch }}/netoptimizer/*.{ipk,apk}
```


## 六、部署与测试

### 6.1 部署方式

| 方式 | 适用场景 | 命令 |
|------|---------|------|
| **完整固件刷写** | 新装/重置设备 | 通过 Firmware Selector 刷写 `.bin` |
| **IPK/APK 包安装** | 已有 OpenWrt 系统 | `opkg install` / `apk add` |
| **一键部署脚本** | 快速测试 | 脚本自动安装所有组件 |

### 6.2 测试计划

| 测试项 | 测试方法 | 预期结果 |
|--------|---------|---------|
| 固件刷写 | 刷入测试设备 | 正常启动，LuCI 可访问 |
| 基础网络 | ping 外网 | 连通性正常 |
| 流量统计 | 浏览网页后查看 nlbwmon | 显示流量数据和域名 |
| PBR 策略 | 配置基于域名的策略 | 流量走指定接口 |
| SQM | 开启后测速 | 延迟（Bufferbloat）降低 |
| sqm-autorate | 大流量下载 | 带宽自动调整 |
| dae 代理 | 访问代理网站 | 正常代理，性能无显著损耗 |
| Neko Master | 查看面板 | 数据实时上报 |

### 6.3 性能基准

| 指标 | 目标值 | 测试工具 |
|------|--------|---------|
| 路由转发性能 | ≥ 950 Mbps（x86_64） | iperf3 |
| dae 代理开销 | ≤ 5% CPU | 压力测试 |
| SQM 延迟 | ≤ 10ms 增加（优秀 ≤ 5ms） | bufferbloat 测试 |
| WebSocket 延迟 | ≤ 100ms | Neko Master 内置 |


## 七、文档与发布

### 7.1 文档结构

```
docs/
├── README.md                 # 项目概述
├── INSTALL.md                # 安装指南（固件刷写/包安装）
├── CONFIG.md                 # 配置指南（各模块详细配置）
├── PBR-GUIDE.md              # 策略路由配置示例
├── SQM-GUIDE.md              # 带宽管理调优指南
├── DAE-GUIDE.md              # 透明代理配置指南
├── NEKO-GUIDE.md             # Neko Master 部署指南
├── FAQ.md                    # 常见问题
└── DEVELOPER.md              # 开发者文档（编译/二次开发）
```

### 7.2 发布渠道

| 渠道 | 内容 |
|------|------|
| **GitHub Releases** | 固件镜像（`.bin`）、IPK/APK 包、SHA256 校验 |
| **OpenWrt 论坛** | 发布帖、用户反馈 |
| **项目 Wiki** | 详细文档、配置示例 |
| **Docker Hub** | Neko Master 镜像 |


## 八、维护与迭代

### 8.1 版本规划

| 版本 | 里程碑 | 内容 |
|------|--------|------|
| v1.0.0 | M7（第 12 周） | 首个正式版，所有核心功能完整 |
| v1.1.0 | +4 周 | Prometheus + Grafana 集成 |
| v1.2.0 | +8 周 | ClickHouse 后端支持 |
| v2.0.0 | +6 月 | Home Assistant 集成、告警系统 |

### 8.2 维护策略

- **安全更新**：跟随 OpenWrt 稳定版安全公告及时更新
- **功能更新**：每 2-4 周发布一个小版本
- **LTS 支持**：每个大版本支持 12 个月

### 8.3 风险与应对

| 风险 | 影响 | 应对措施 |
|------|------|---------|
| OpenWrt 24.10 已 EOL（2026 年 9 月） | 双版本维护成本高 | 主攻 25.12/apk，放弃 `.ipk` 长期打包线 |
| 官方固件/ImageBuilder 内核未开 BTF | dae/daed 启动失败 | SDK 自编开 BTF（默认）/ ImmortalWrt / 补装 vmlinux-btf（见 5.4） |
| Neko Master 无法采集 dae 数据 | 分析面板缺位 | 定位为可选扩展，需 mihomo/OpenClash 数据源；默认路径用 nlbwmon + LuCI |
| sqm-autorate 不在官方源 | 依赖第三方 Release | 转存上游 apk 至自有 feed 并锁定版本（v0.6.1） |
| Flash 空间不足 | 固件无法刷入 | 使用 squashfs 压缩，精确控制包列表 |
| 第三方源不稳定 | 构建失败 | 锁定 commit 版本，自托管关键包 |


## 九、项目资源清单

### 9.1 代码仓库

| 仓库 | 用途 | URL |
|------|------|-----|
| openwrt-netoptimizer | 主项目 | GitHub 组织仓库 |
| openwrt-netoptimizer-packages | IPK/APK 包 | GitHub Releases |
| openwrt-netoptimizer-docs | 文档 | GitHub Wiki |

### 9.2 依赖的第三方仓库

| 仓库 | 用途 | URL |
|------|------|-----|
| stangri/pbr | 策略路由上游（已在官方源，仅作新版跟进参考） | https://github.com/stangri/pbr |
| kenzok8/openwrt-daede | dae/daed 一体包 + vmlinux-btf 补丁包 | https://github.com/kenzok8/openwrt-daede |
| kenzok8/imagebuilder | 带 BTF 内核的在线固件生成（ImmortalWrt） | https://github.com/kenzok8/imagebuilder |
| sqm-autorate/sqm-autorate | 自适应带宽 Lua 版（官方源无，用其 Release apk/ipk） | https://github.com/sqm-autorate/sqm-autorate |
| foru17/neko-master | 流量分析面板（可选，数据源为 Clash/Mihomo/Surge） | https://github.com/foru17/neko-master |

### 9.3 硬件测试平台

| 平台 | 架构 | 用途 |
|------|------|------|
| x86_64 软路由 | x86_64 | 主测试平台 |
| NanoPi R4S/R5S | aarch64 | ARM 测试平台 |
| 任意 MT7621 设备 | mipsel_24kc | MIPS 兼容性测试（**无 eBPF/BTF，仅测基础功能，不含 dae/daed**） |