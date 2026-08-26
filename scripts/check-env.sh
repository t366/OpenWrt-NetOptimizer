#!/bin/sh

log() { printf '[check-env] %s\n' "$*"; }
bad() { printf '[check-env] MISSING: %s\n' "$*" >&2; }

log "arch: $(uname -m)"
log "kernel: $(uname -r)"
log "openwrt release: $(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_RELEASE | cut -d"'" -f2)"

if command -v apk >/dev/null 2>&1; then
	log "package manager: apk (OpenWrt 25.12+)"
elif command -v opkg >/dev/null 2>&1; then
	log "package manager: opkg (OpenWrt 24.10 and earlier)"
else
	bad "package manager"
fi

if [ -r /sys/kernel/btf/vmlinux ]; then
	log "kernel BTF (/sys/kernel/btf/vmlinux): present"
else
	bad "kernel BTF (/sys/kernel/btf/vmlinux) - dae/daed cannot run, install kenzok8/vmlinux-btf or flash BTF firmware"
fi

if grep -qs cgroup /proc/mounts && [ -d /sys/fs/cgroup ]; then
	log "cgroup: mounted"
else
	bad "cgroup mount - required by dae eBPF programs"
fi

if command -v tc >/dev/null 2>&1 && tc qdisc show 2>/dev/null | grep -q cake; then
	log "CAKE qdisc: active"
elif command -v tc >/dev/null 2>&1; then
	log "CAKE qdisc: not enabled (configure SQM to activate)"
else
	bad "tc utility (install ip-full/tc from package manager)"
fi

for svc in nlbwmon pbr sqm sqm-autorate dae daed; do
	if [ -x "/etc/init.d/${svc}" ]; then
		state="$(/etc/init.d/"${svc}" enabled 2>/dev/null && echo enabled || echo disabled)"
		log "service ${svc}: installed, ${state}"
	else
		log "service ${svc}: not installed"
	fi
done
