# Checklist — Nhả Secure Input (không Restart)

Dùng khi: không gõ được tiếng Việt / Barrier chuột OK nhưng **phím sang Windows chết** / EVKey im.

## 0a) Hai lớp lỗi (đọc trước)

| Lớp | Dấu hiệu | Lệnh |
|-----|----------|------|
| **A — Secure Input** | `SECURE_INPUT_ACTIVE=yes`; Barrier phím Win chết | `nha-secure-input` → Log Out nếu kẹt lâu |
| **B — Barrier remap** | SI=off nhưng mất chữ trên Mac (đúng chữ bị map) | Comment mọi `keystroke(Super\|Meta+chữ)` trong `~/barrier.conf`; escape: `fix-keyboard-grabbers --stop` |

Incident B (2026-10-17): A/B → Barrier; root cause = Super/Meta letter remaps. **Đã tắt hết** — không bật lại. Confirm `asv`+`cxz` OK với Barrier ON.

## 0) Chẩn đoán nhanh (30s)
```bash
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/diagnose.sh
# hoặc: diagnose-go-tieng-viet
```

Ghi lại: `SECURE_INPUT_PID`, `COMM`, `ETIME`, `CAUSE_1`.

| Quan sát | Ý nghĩa |
|----------|---------|
| PID = 0 / ACTIVE=no | SI đã off → nhảy bước 3 |
| Holder = app có UI (Cursor, terminal…) | Đóng dialog / Quit app → diagnose lại |
| Holder = `loginwindow`, không dialog, ETIME lớn | Soft lock có thể fail → chuẩn bị Log Out (bước 2c) |

## 1) Soft path — khóa màn hình (ưu tiên)

```bash
nha-secure-input
# hoặc: fix-barrier-keyboard --lock
# hoặc: Ctrl+Cmd+Q
```

Sau khi khóa:

1. Mở khóa bằng **mật khẩu** (tránh Touch ID).
2. Chạy:

```bash
fix-barrier-keyboard
# hoặc poll tự động:
fix-barrier-keyboard --wait
```

Thành công khi: `SECURE_INPUT=off` và gõ được sang Win.

## 2) Soft path fail — Log Out (bắt buộc khi deep-stuck)

Dấu hiệu: sau unlock, `diagnose` / `nha-secure-input --check` vẫn SI=ON; holder vẫn `loginwindow`; không có password UI.

1. **Apple menu → Log Out** (không cần Restart máy).
2. Login lại.
3. Chạy:

```bash
fix-barrier-keyboard
```

4. Xác nhận gõ phím Mac → Windows OK.

Restart đầy đủ máy chỉ khi Log Out vẫn không đủ.

## 3) Barrier sau khi SI = off

```bash
fix-barrier-keyboard
```

- Script restart `barriers` / mở Barrier.
- Nếu `barriers` chưa chạy: mở Barrier UI → Start.
- Nếu SI=off mà vẫn không gõ: kiểm tra Accessibility cho Barrier (System Settings → Privacy).

## 4) Phân biệt hai “Secure” (hay nhầm)

| Kiểu | Dấu hiệu | Cách tắt |
|------|----------|----------|
| iTerm Secure Keyboard Entry | Icon chìa khóa cửa sổ iTerm | Menu iTerm2 → bỏ tick Secure Keyboard Entry |
| macOS Secure Input | `kCGSSessionSecureInputPID ≠ 0` | Theo bước 1 → 2 ở trên |

## 5) Gõ tiếng Việt

- **Ổn định:** VietnameseIM **Telex** hệ thống.
- EVKey chỉ khi còn dùng: `fix-go-tieng-viet --evkey` (sau khi SI=off).

## 6) Phòng ngừa

```bash
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/install-secure-input-watchdog.sh
```

Watchdog: cùng PID ≥ ~90s → notify + auto-lock. Không thay Log Out khi deep-stuck.

## 2b) SI=off mà vẫn mất chữ trên Mac

```bash
fix-keyboard-grabbers           # soft
fix-keyboard-grabbers --stop    # tắt Barrier/Logi/ChromeRD/Lightshot
# gõ thử asv123 trên Mac
fix-keyboard-grabbers --restore # hướng dẫn bật lại
```

## Lệnh một dòng

| Mục đích | Lệnh |
|----------|------|
| Diagnose | `diagnose-go-tieng-viet` |
| Nhả SI | `nha-secure-input` |
| Barrier sau SI off | `fix-barrier-keyboard` |
| Chờ SI tắt rồi Barrier | `fix-barrier-keyboard --wait` |
| Mất chữ khi SI=off | `fix-keyboard-grabbers --stop` |
| Soft fix VN | `fix-go-tieng-viet` |
Chi tiết kỹ thuật: [CONTEXT.md](CONTEXT.md), [REFERENCE.md](REFERENCE.md), [specs/001-secure-input-release/spec.md](specs/001-secure-input-release/spec.md).
