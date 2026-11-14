#!/usr/bin/env bash
# Build U-Boot for the AD5X (Ingenic X2600) from the release + patches/.
#
#   u-boot/build.sh            tree from the v$UVER tarball + patches/
#   USRC=DIR u-boot/build.sh   build a development tree as it is
#                              (git, patches committed on v$UVER)
#   JOBS=8, O=DIR              parallelism, output directory
#
# Output: $O/u-boot.bin, U-Boot proper linked at 0x80100000 (no SPL).
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
UVER=2026.10
# GitHub's archive of the v2026.10 tag (ftp.denx.de's tarball is the same tree)
USHA256=f943a88389c8fd70a6b0d061a88267465e143c7ca6ea2b75837ab20f5b60c739
UURL=https://github.com/u-boot/u-boot/archive/refs/tags/v$UVER.tar.gz
WORK=${WORK:-$HOME/workspace/u-boot-ad5x-build}
TOOLBIN=${TOOLBIN:-$REPO/buildroot/output/host/bin}
JOBS=${JOBS:-$(nproc)}
O=${O:-$WORK/out}

log() { printf '\n=== %s\n' "$*"; }

if [ -z "${USRC:-}" ]; then
	USRC=$WORK/u-boot-$UVER
	tarball=$WORK/u-boot-$UVER.tar.gz
	mkdir -p "$WORK"
	if [ ! -f "$tarball" ]; then
		log "fetch u-boot $UVER"
		curl -fsSL -o "$tarball.part" "$UURL"
		mv "$tarball.part" "$tarball"
	fi
	echo "$USHA256  $tarball" | sha256sum -c --quiet
	log "unpack + patches"
	rm -rf "$USRC"
	tar xzf "$tarball" -C "$WORK"
	for p in "$HERE"/patches/*.patch; do
		patch -d "$USRC" -p1 --quiet < "$p"
	done
fi

# Buildroot's toolchain; a clean PATH (Buildroot-built tools dislike spaces)
export PATH=$TOOLBIN:/usr/local/bin:/usr/bin:/bin
M=(make -C "$USRC" O="$O" CROSS_COMPILE=mipsel-linux-)
log "build ($JOBS jobs)"
"${M[@]}" ad5x_defconfig
"${M[@]}" -j"$JOBS"
ls -l "$O/u-boot.bin"
