#!/usr/bin/env bash
# Cài LaunchAgent: kiểm tra Secure Input mỗi 30s, kẹt >= 90s → tự khóa màn hình.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHDOG="$SCRIPT_DIR/secure-input-watchdog.sh"
NHA="$SCRIPT_DIR/nha-secure-input.sh"
BIN_DIR="$HOME/.local/bin"
PLIST="$HOME/Library/LaunchAgents/com.user.secure-input-watchdog.plist"
LABEL="com.user.secure-input-watchdog"

chmod +x "$WATCHDOG" "$NHA" \
  "$SCRIPT_DIR/fix-nhanh.sh" "$SCRIPT_DIR/diagnose.sh" \
  "$SCRIPT_DIR/fix-barrier-keyboard.sh" \
  "$SCRIPT_DIR/fix-keyboard-grabbers.sh" \
  "$SCRIPT_DIR/validate-watchdog-state.sh" 2>/dev/null || true
mkdir -p "$BIN_DIR" "$HOME/Library/LaunchAgents"

ln -sf "$NHA" "$BIN_DIR/nha-secure-input"
ln -sf "$SCRIPT_DIR/fix-nhanh.sh" "$BIN_DIR/fix-go-tieng-viet"
ln -sf "$SCRIPT_DIR/diagnose.sh" "$BIN_DIR/diagnose-go-tieng-viet"
ln -sf "$SCRIPT_DIR/fix-barrier-keyboard.sh" "$BIN_DIR/fix-barrier-keyboard"
ln -sf "$SCRIPT_DIR/fix-keyboard-grabbers.sh" "$BIN_DIR/fix-keyboard-grabbers"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${WATCHDOG}</string>
  </array>
  <key>StartInterval</key>
  <integer>30</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/secure-input-watchdog.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/secure-input-watchdog.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>SECURE_INPUT_STUCK_SECONDS</key>
    <string>90</string>
    <key>SECURE_INPUT_POST_UNLOCK_GRACE</key>
    <string>60</string>
    <key>SECURE_INPUT_REOPEN_BARRIER</key>
    <string>1</string>
    <key>SECURE_INPUT_LOCK_COOLDOWN</key>
    <string>120</string>
  </dict>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null || true

echo "OK watchdog installed: $PLIST"
echo "  Interval: 30s | Auto-lock after Secure Input stuck >= 90s"
echo "  Post-unlock grace: 60s (no re-lock loop) | Reopen Barrier when SI clears"
echo "  Manual release: nha-secure-input   (hoặc Ctrl+Cmd+Q rồi mở khóa bằng mật khẩu)"
echo "  Validate state: bash $SCRIPT_DIR/validate-watchdog-state.sh --self-test"
echo "  Uninstall: launchctl bootout gui/\$(id -u)/${LABEL} && rm -f $PLIST"
