#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
VERIFY_DIR="$ROOT_DIR/.build/verify"

mkdir -p "$VERIFY_DIR"

swiftc \
    -parse-as-library \
    -emit-module \
    -emit-library \
    -static \
    -module-name ServerMonitorCore \
    "$ROOT_DIR"/Sources/ServerMonitorCore/*.swift \
    -emit-module-path "$VERIFY_DIR/ServerMonitorCore.swiftmodule" \
    -o "$VERIFY_DIR/libServerMonitorCore.a"

swiftc \
    -I "$VERIFY_DIR" \
    -L "$VERIFY_DIR" \
    -lServerMonitorCore \
    "$ROOT_DIR/Tests/CoreChecks.swift" \
    -o "$VERIFY_DIR/verify_core"

"$VERIFY_DIR/verify_core"

swiftc \
    -parse-as-library \
    -I "$VERIFY_DIR" \
    -L "$VERIFY_DIR" \
    -lServerMonitorCore \
    -framework Combine \
    "$ROOT_DIR/Sources/ServerMonitor/RemoteServerService.swift" \
    "$ROOT_DIR/Sources/ServerMonitor/ServerMonitorViewModel.swift" \
    "$ROOT_DIR/Sources/ServerMonitor/ServerStatus.swift" \
    "$ROOT_DIR/Tests/ModelChecks.swift" \
    -o "$VERIFY_DIR/verify_model"

"$VERIFY_DIR/verify_model"
