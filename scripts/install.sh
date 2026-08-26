#!/bin/sh
set -e

SQMA_REPO="sqm-autorate/sqm-autorate"
SQMA_TAG="v0.6.1"
SQMA_BASE="https://github.com/${SQMA_REPO}/releases/download/${SQMA_TAG}"
DAEDE_SETUP="https://down.dllkids.xyz/openwrt-feed/openwrt-feed-setup.sh"

CORE_PKGS="nlbwmon luci-app-nlbwmon v2ray-geoip v2ray-geosite pbr luci-app-pbr sqm-scripts luci-app-sqm kmod-sched-cake"
PROXY_PKGS="kmod-sched-bpf kmod-veth kmod-xdp-sockets-diag kmod-nft-tproxy dae daed luci-app-daede"

log() { printf '[netoptimizer] %s\n' "$*"; }
warn() { printf '[netoptimizer] WARNING: %s\n' "$*" >&2; }
die() { printf '[netoptimizer] ERROR: %s\n' "$*" >&2; exit 1; }

detect_pm() {
	if command -v apk >/dev/null 2>&1; then
		PM=apk
	elif command -v opkg >/dev/null 2>&1; then
		PM=opkg
	else
		die "neither apk nor opkg found, not an OpenWrt system?"
	fi
	log "package manager: ${PM}"
}

check_env() {
	[ "$(id -u)" -eq 0 ] || die "must run as root"

	if [ ! -r /sys/kernel/btf/vmlinux ]; then
		warn "/sys/kernel/btf/vmlinux not found"
		warn "dae/daed will fail to start without BTF"
		warn "install the matching kenzok8/vmlinux-btf package or flash a BTF-enabled firmware (see docs section 5.4)"
	else
		log "kernel BTF: ok"
	fi

	if grep -qs '^mwan3' /etc/config/mwan3 2>/dev/null; then
		warn "mwan3 detected: pbr and mwan3 conflict, disable one of them after install"
	fi
}

setup_daede_feed() {
	log "setting up kenzok8 daede feed"
	wget -qO- "$DAEDE_SETUP" | sh || warn "daede feed setup failed, proxy components may be unavailable"
}

replace_dnsmasq() {
	case "$PM" in
	apk)
		if apk info -e dnsmasq >/dev/null 2>&1; then
			log "removing dnsmasq before installing dnsmasq-full"
			apk del dnsmasq >/dev/null 2>&1 || true
		fi
		;;
	opkg)
		if opkg list-installed 2>/dev/null | grep -q '^dnsmasq - '; then
			opkg remove dnsmasq >/dev/null 2>&1 || true
		fi
		;;
	esac
}

install_core() {
	log "installing core packages"
	case "$PM" in
	apk) apk update && apk add $CORE_PKGS $PROXY_PKGS ;;
	opkg) opkg update && opkg install $CORE_PKGS $PROXY_PKGS ;;
	esac
}

install_sqm_autorate() {
	local tmp
	tmp="$(mktemp -d)"

	log "installing sqm-autorate ${SQMA_TAG} from upstream releases"
	case "$PM" in
	apk)
		wget -qO "${tmp}/lua-vstruct.apk" "${SQMA_BASE}/lua-vstruct-2.1.1-r1.apk" || { warn "download failed"; rm -rf "$tmp"; return 0; }
		wget -qO "${tmp}/sqm-autorate.apk" "${SQMA_BASE}/sqm-autorate-0.6.1-r1.apk" || { warn "download failed"; rm -rf "$tmp"; return 0; }
		apk add --allow-untrusted "${tmp}/lua-vstruct.apk" "${tmp}/sqm-autorate.apk"
		;;
	opkg)
		wget -qO "${tmp}/lua-vstruct.ipk" "${SQMA_BASE}/lua-vstruct_2.1.1-1_all.ipk" || { warn "download failed"; rm -rf "$tmp"; return 0; }
		wget -qO "${tmp}/sqm-autorate.ipk" "${SQMA_BASE}/sqm-autorate_0.6.1-1_all.ipk" || { warn "download failed"; rm -rf "$tmp"; return 0; }
		opkg install "${tmp}/lua-vstruct.ipk" "${tmp}/sqm-autorate.ipk"
		;;
	esac
	rm -rf "$tmp"
}

post_install() {
	cat <<EOF

[netoptimizer] installation finished. next steps:
  1. LuCI -> Services -> daede : choose backend (dae/daed), import config
  2. LuCI -> Services -> PBR   : add policy rules (do NOT enable mwan3 together)
  3. LuCI -> Network -> SQM/QoS: set dl/ul bandwidth, enable CAKE
  4. edit /etc/config/sqm-autorate, then run:
       /etc/init.d/sqm-autorate enable && /etc/init.d/sqm-autorate start
  5. nlbwmon stats: LuCI -> Status -> Bandwidth Monitor
EOF
}

main() {
	detect_pm
	check_env
	setup_daede_feed
	replace_dnsmasq
	install_core
	install_sqm_autorate
	post_install
}

main "$@"
