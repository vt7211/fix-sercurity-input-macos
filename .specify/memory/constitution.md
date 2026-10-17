<!--
Sync Impact Report:
- Version: 1.0.0 (initial for this skill project)
- Scope: macOS Vietnamese typing + Secure Input + Barrier keyboard
-->
# kiem-tra-go-tieng-viet Constitution

## Core Principles

### I. Diagnose Before Kill
Luôn chạy `scripts/diagnose.sh` trước. Không kill process / không khóa
màn hình trừ khi user yêu cầu sửa hoặc script fix được gọi tường minh.
Rationale: Secure Input hay bị nhầm với EVKey/Accessibility; kill mù
làm mất phiên làm việc.

### II. Secure Input Is Absolute
Khi `kCGSSessionSecureInputPID ≠ 0`, macOS chặn CGEventTap toàn hệ thống.
Hệ quả: EVKey, Barrier (server), mọi phần mềm KVM bắt phím đều chết bàn phím.
Không có public API để force-clear Secure Input của process khác.
Rationale: Đây là thiết kế bảo mật Apple, không phải bug EVKey/Barrier.

### III. Prefer Soft Release Over Restart
Thứ tự nhả Secure Input (nhẹ → nặng):
1. Đóng dialog password / Quit app giữ PID
2. `nha-secure-input` / `SACLockScreenImmediate` → mở khóa bằng **mật khẩu** (tránh Touch ID)
3. **Log Out** (không cần Restart máy) — bắt buộc khi `loginwindow` kẹt nhiều giờ
4. Restart máy — chỉ khi Log Out không đủ
Rationale: Restart mở lại hàng chục app; user coi đây là không chấp nhận được nếu lặp lại.

### IV. Telex Hệ Thống Là Đường Ổn Định Cho Gõ VN
Khi EVKey liên tục hỏng vì Secure Input: ưu tiên **VietnameseIM Telex**
(hệ thống) cho gõ tiếng Việt. Skill vẫn hỗ trợ EVKey nhưng không bắt buộc.
Rationale: Telex không phụ thuộc CGEventTap → sống sót khi Secure Input bật
(trong hầu hết app native; Barrier sang Win vẫn chết).

### V. Scripts Must Work on Current macOS
Không phụ thuộc `CGSession` (đã bị gỡ trên macOS mới). Khóa màn hình qua
`login.framework` → `SACLockScreenImmediate()`. Watchdog và fix scripts
phải idempotent, log rõ, không sửa preference hệ thống nếu không cần.
Rationale: Script cũ im lặng fail → user tưởng đã “khóa” nhưng không có gì xảy ra.

### VI. Speckit Is Source of Truth for the Long Bug
Mọi phát hiện lâu dài (loginwindow kẹt 16h+, Barrier, AnyDesk autostart,
Touch ID không nhả SI) MUST được ghi vào `specs/` + `CONTEXT.md`, không
chỉ trong chat. Rationale: Lỗi nghiêm trọng kéo dài; context chat bị mất.

### VII. Simplicity
Thêm script chỉ khi tái sử dụng được. Không cài daemon nặng; LaunchAgent
watchdog 30s là đủ. Không tắt SIP / không private SPI nguy hiểm ngoài
`SACLockScreenImmediate` đã kiểm chứng.

## Project Context

- Root: `~/.cursor/skills/kiem-tra-go-tieng-viet/`
- Entry: `SKILL.md` (agent instructions)
- Scripts: `scripts/*.sh` + symlinks `~/.local/bin/{diagnose-go-tieng-viet,fix-go-tieng-viet,nha-secure-input,fix-barrier-keyboard}`
- Watchdog: `~/Library/LaunchAgents/com.user.secure-input-watchdog.plist`
- Speckit: `.specify/` + `.cursor/skills/speckit-*`

## Stack & Constraints

| Thành phần | Ghi chú |
|------------|---------|
| macOS Secure Input | `ioreg` → `kCGSSessionSecureInputPID`; Carbon `IsSecureEventInputEnabled` |
| Khóa màn hình | `ctypes` → `login.framework` `SACLockScreenImmediate` |
| EVKey | CGEventTap — chết khi SI on |
| Barrier | `barriers` server trên Mac — (1) phím sang Win chết khi SI on; (2) A/B 2026-10-17: Barrier alone có thể làm mất chữ `a`/`s`/`v` **trên Mac** (SI=off) — quit Barrier để nhả |
| AnyDesk | LaunchAgents/Daemons `com.philandro.anydesk.*` — đã Disabled RunAtLoad trên máy user (2026-10-17) |

## Governance

- Version: 1.0.0
- Ratified: 2026-10-17
- Last amended: 2026-10-17
- Amend via Speckit constitution skill khi đổi nguyên tắc nhả SI / thêm tool KVM.
