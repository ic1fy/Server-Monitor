#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
BUILD_DIR="$ROOT_DIR/.build"
OUTPUT_DIR="$ROOT_DIR/outputs"
APP_DIR="$OUTPUT_DIR/Server Monitor.app"
ICON_PNG="$BUILD_DIR/AppIcon-1024.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:--}"

architectures=(arm64)
if [[ -n "${SERVER_MONITOR_ARCHS:-}" ]]; then
    architectures=(${=SERVER_MONITOR_ARCHS})
fi

mkdir -p "$BUILD_DIR/clang-module-cache" "$OUTPUT_DIR"

export CLANG_MODULE_CACHE_PATH="$BUILD_DIR/clang-module-cache"

cd "$ROOT_DIR"
binary_inputs=()
for architecture in "${architectures[@]}"; do
    architecture_dir="$BUILD_DIR/direct-$architecture"
    mkdir -p "$architecture_dir"
    target="$architecture-apple-macosx14.0"

    swiftc \
        -target "$target" \
        -parse-as-library \
        -emit-module \
        -emit-library \
        -static \
        -O \
        -whole-module-optimization \
        -warnings-as-errors \
        -module-name ServerMonitorCore \
        "$ROOT_DIR"/Sources/ServerMonitorCore/*.swift \
        -emit-module-path "$architecture_dir/ServerMonitorCore.swiftmodule" \
        -o "$architecture_dir/libServerMonitorCore.a"

    swiftc \
        -target "$target" \
        -I "$architecture_dir" \
        -L "$architecture_dir" \
        -lServerMonitorCore \
        -framework AppKit \
        -framework SwiftUI \
        -framework Combine \
        -O \
        -whole-module-optimization \
        -warnings-as-errors \
        "$ROOT_DIR"/Sources/ServerMonitor/*.swift \
        -o "$architecture_dir/ServerMonitor"

    binary_inputs+=("$architecture_dir/ServerMonitor")
done

swift "$ROOT_DIR/scripts/generate_app_icon.swift" "$ICON_PNG"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

for spec in \
    "16 icon_16x16.png" \
    "32 icon_16x16@2x.png" \
    "32 icon_32x32.png" \
    "64 icon_32x32@2x.png" \
    "128 icon_128x128.png" \
    "256 icon_128x128@2x.png" \
    "256 icon_256x256.png" \
    "512 icon_256x256@2x.png" \
    "512 icon_512x512.png" \
    "1024 icon_512x512@2x.png"; do
    size="${spec%% *}"
    name="${spec#* }"
    /usr/bin/sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET_DIR/$name" >/dev/null
done
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/AppIcon.icns"

stage_dir="$(mktemp -d "$OUTPUT_DIR/.server-monitor-build.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
staged_app="$stage_dir/Server Monitor.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"

if (( ${#binary_inputs[@]} == 1 )); then
    cp "$binary_inputs[1]" "$staged_app/Contents/MacOS/ServerMonitor"
else
    /usr/bin/lipo -create "${binary_inputs[@]}" -output "$staged_app/Contents/MacOS/ServerMonitor"
fi

cp "$ROOT_DIR/Resources/Info.plist" "$staged_app/Contents/Info.plist"
cp "$BUILD_DIR/AppIcon.icns" "$staged_app/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$staged_app/Contents/Info.plist" >/dev/null

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    /usr/bin/codesign --force --sign - "$staged_app"
else
    /usr/bin/codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$staged_app"
fi
/usr/bin/codesign --verify --deep --strict "$staged_app"

rm -rf "$APP_DIR"
mv "$staged_app" "$APP_DIR"

echo "$APP_DIR"
