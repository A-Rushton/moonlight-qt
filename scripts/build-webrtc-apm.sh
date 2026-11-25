#!/bin/bash
# Builds webrtc-audio-processing as a universal static library in libs/webrtc-apm/mac
set -euo pipefail

VERSION=2.1
URL=https://freedesktop.org/software/pulseaudio/webrtc-audio-processing/webrtc-audio-processing-$VERSION.tar.xz
SHA256=ae9302824b2038d394f10213cab05312c564a038434269f11dbf68f511f9f9fe
ARCHS="arm64 x86_64"

SOURCE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR=$SOURCE_ROOT/libs/webrtc-apm/mac

fail()
{
	echo "$1" 1>&2
	exit 1
}

if [ "$(cat "$OUT_DIR/VERSION" 2>/dev/null)" == "$VERSION" ]; then
	echo "webrtc-audio-processing $VERSION already built"
	exit 0
fi

command -v meson >/dev/null || fail "meson not found"
command -v ninja >/dev/null || fail "ninja not found"

QMAKE=$(command -v qmake6 || command -v qmake) || fail "qmake not found"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo 'message($$QMAKE_MACOSX_DEPLOYMENT_TARGET)' > "$WORK_DIR/target.pro"
MIN_MACOS=$(cd "$WORK_DIR" && "$QMAKE" -o /dev/null target.pro 2>&1 | sed -n 's/^Project MESSAGE: //p')
[[ "$MIN_MACOS" =~ ^[0-9]+(\.[0-9]+)*$ ]] || fail "Unable to determine the Qt deployment target"
echo "Deployment target: macOS $MIN_MACOS"

curl -fsSL --retry 3 -o "$WORK_DIR/src.tar.xz" "$URL"
echo "$SHA256  $WORK_DIR/src.tar.xz" | shasum -a 256 -c - || fail "Checksum mismatch for $URL"
tar -xf "$WORK_DIR/src.tar.xz" -C "$WORK_DIR"
SRC_DIR=$WORK_DIR/webrtc-audio-processing-$VERSION

MERGED=()
for ARCH in $ARCHS; do
	case $ARCH in
		arm64) CPU_FAMILY=aarch64 ;;
		x86_64) CPU_FAMILY=x86_64 ;;
	esac

	FLAGS="'-arch', '$ARCH', '-mmacosx-version-min=$MIN_MACOS'"
	cat > "$WORK_DIR/cross-$ARCH.ini" <<EOF
[binaries]
c = 'clang'
cpp = 'clang++'
ar = 'ar'
strip = 'strip'

[built-in options]
c_args = [$FLAGS]
cpp_args = [$FLAGS]
c_link_args = [$FLAGS]
cpp_link_args = [$FLAGS]

[host_machine]
system = 'darwin'
cpu_family = '$CPU_FAMILY'
cpu = '$ARCH'
endian = 'little'
EOF

	BUILD_DIR=$WORK_DIR/build-$ARCH
	meson setup "$BUILD_DIR" "$SRC_DIR" \
		--cross-file "$WORK_DIR/cross-$ARCH.ini" \
		--buildtype=release \
		--default-library=static \
		--prefix "$WORK_DIR/install-$ARCH" \
		-Dwrap_mode=forcefallback
	meson compile -C "$BUILD_DIR"
	meson install -C "$BUILD_DIR" --quiet

	LIBS=("$WORK_DIR/install-$ARCH/lib/libwebrtc-audio-processing-2.a")
	while IFS= read -r LIB; do
		LIBS+=("$LIB")
	done < <(find "$BUILD_DIR/subprojects" -name '*.a' | sort)
	[ ${#LIBS[@]} -gt 1 ] || fail "No abseil libraries found for $ARCH"

	libtool -static -no_warning_for_no_symbols -o "$WORK_DIR/libwebrtc-apm-$ARCH.a" "${LIBS[@]}"
	MERGED+=("$WORK_DIR/libwebrtc-apm-$ARCH.a")
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR/lib"
lipo -create -output "$OUT_DIR/lib/libwebrtc-apm.a" "${MERGED[@]}"
INC_DIR=$WORK_DIR/install-arm64/include
[ -d "$INC_DIR/absl" ] || fail "abseil headers were not installed"
cp -R "$INC_DIR/webrtc-audio-processing-2" "$OUT_DIR/include"
cp -R "$INC_DIR/absl" "$OUT_DIR/include/absl"
echo "$VERSION" > "$OUT_DIR/VERSION"
echo "Built $OUT_DIR"
