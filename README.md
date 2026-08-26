# OpenWrt-NetOptimizer

OpenWrt 一体化网络监控与智能链路优化系统。将流量监控（nlbwmon）、策略路由（pbr）、
自适应带宽管理（SQM + sqm-autorate）、高性能透明代理（dae/daed，eBPF）整合为
统一的软件包与固件。

完整方案见 [《OpenWrt-NetOptimizer 完整项目方案》](./OpenWrt-NetOptimizer%20完整项目方案.md)。

## 仓库结构

```
├── openwrt-netoptimizer/          # meta 软件包（聚合所有组件依赖）
│   ├── Makefile                   # OpenWrt 包构建定义
│   └── files/
│       ├── etc/config/netoptimizer        # 总控 UCI 配置
│       └── etc/uci-defaults/99-netoptimizer  # 首次安装初始化（sysctl/nlbwmon 缓冲区）
├── scripts/
│   ├── install.sh                 # 一键部署脚本（apk/opkg 自适应）
│   └── check-env.sh               # 运行环境诊断（BTF/cgroup/CAKE/服务状态）
├── .github/workflows/build.yml    # CI：SDK 编译 x86_64 / aarch64 包
└── feeds.conf.example             # SDK 全量编译用第三方 feeds
```

## 关键前提

- **OpenWrt 25.12+**（apk 包管理器）；24.10 已 EOL，仅社区兼容
- **内核必须开启 BTF**：dae/daed 运行时读取 `/sys/kernel/btf/vmlinux`，
  官方固件默认未开启。满足方式：
  1. SDK 自编内核开 `CONFIG_DEBUG_INFO_BTF=y`（推荐）
  2. ImmortalWrt 25.12 固件（默认开启）
  3. 补装 [kenzok8/vmlinux-btf](https://github.com/kenzok8/vmlinux-btf)
- **pbr 与 mwan3 二选一**，同时启用会冲突

## 快速开始

### 在已有 OpenWrt 系统上部署

```bash
wget -qO - https://raw.githubusercontent.com/your-org/openwrt-netoptimizer/main/scripts/install.sh | sh
```

或克隆后执行：

```bash
sh scripts/install.sh
sh scripts/check-env.sh   # 验证环境与服务状态
```

### SDK 编译软件包

```bash
# 以 25.12.5 x86_64 为例（25.12 起 SDK 使用 zstd 压缩）
curl -LO https://downloads.openwrt.org/releases/25.12.5/targets/x86/64/openwrt-sdk-25.12.5-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst
tar --zstd -xf openwrt-sdk-*.tar.zst
cd openwrt-sdk-*
cp -r /path/to/OpenWrt-NetOptimizer/openwrt-netoptimizer package/
./scripts/feeds update -a && ./scripts/feeds install -a
make menuconfig   # Network -> openwrt-netoptimizer 选 <M>
make package/openwrt-netoptimizer/compile V=s
```

### 构建完整固件

三条路线（详见方案文档 5.4 节）：

| 路线 | 场景 |
|------|------|
| A. SDK 全量编译（默认） | 正式发布，BTF 有保障 |
| B. [kenzok8/imagebuilder](https://github.com/kenzok8/imagebuilder) 在线生成 | 快速测试（ImmortalWrt，内核自带 BTF） |
| C. 官方 ImageBuilder | 仅监控类固件（**不含 dae/daed**） |

## 组件清单

| 组件 | 来源 | 说明 |
|------|------|------|
| nlbwmon + luci-app-nlbwmon | 官方源 | 按设备/IP 流量统计 |
| dnsmasq-full | 官方源 | 域名解析关联（替换默认 dnsmasq） |
| v2ray-geoip/geosite | 官方源 | 地理位置与域名分类数据 |
| pbr + luci-app-pbr | 官方源（25.12.5 为 1.2.2-r20） | 策略路由 |
| sqm-scripts + kmod-sched-cake | 官方源 | CAKE 智能队列 |
| sqm-autorate v0.6.1 | [sqm-autorate/sqm-autorate](https://github.com/sqm-autorate/sqm-autorate) Release | 自适应带宽（Lua 版；官方源无此包） |
| dae/daed/luci-app-daede | [kenzok8/openwrt-daede](https://github.com/kenzok8/openwrt-daede) feed | eBPF 透明代理 |

## 当前状态

- [x] 方案设计与事实核查修订
- [x] meta 软件包骨架（Makefile / UCI 默认配置 / uci-defaults）
- [x] 一键安装脚本与环境诊断脚本
- [x] CI 流水线（gh-action-sdk）
- [x] SDK 25.12.5 实机验证：依赖解析（defconfig 全部选中）、apk 构建、mkndx 索引、
      adbdump 元数据、内容提取（conffiles/uci-defaults 权限）全部通过
- [ ] CI 首次完整依赖编译（dae/daed Go 工具链需大内存环境）
- [ ] 固件 ImageBuilder 路线打通（BTF 内核）
- [ ] 功能集成测试（x86_64 / NanoPi R4S）
