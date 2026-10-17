# Feature Specification: Secure Input Release & Barrier Keyboard

**Feature Branch**: `001-secure-input-release`  
**Created**: 2026-10-17  
**Status**: Complete (2026-10-17) — SC-001 PASS (`win-ok`); Barrier remap fix documented  
**Input**: Lỗi nghiêm trọng kéo dài — Secure Input kẹt (thường `loginwindow`) không UI; EVKey/Telex/Barrier phím sang Windows chết; Restart không chấp nhận được nếu lặp.

**Context docs**: [CONTEXT.md](../../CONTEXT.md), [REFERENCE.md](../../REFERENCE.md), [SKILL.md](../../SKILL.md)

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Nhả Secure Input không Restart (Priority: P1)

User đang làm việc (Cursor, Barrier → Win, nhiều app). Bàn phím Mac → Win chết / EVKey chết. Không thấy dialog password. User muốn nhả SI trong < 1 phút không Restart.

**Why this priority**: Đây là pain chính; Restart phá cả ngày làm việc.

**Independent Test**: Bật SI giả (ô password) hoặc quan sát SI thật → chạy `nha-secure-input` / Log Out path → `diagnose.sh` ra `SECURE_INPUT_ACTIVE=no`.

**Acceptance Scenarios**:

1. **Given** SI held by app còn sống có UI, **When** đóng UI / Quit app + `diagnose`, **Then** SI=off.
2. **Given** SI zombie hoặc loginwindow ngắn, **When** `nha-secure-input` + unlock bằng mật khẩu, **Then** SI=off trong < 30s sau unlock.
3. **Given** SI held by loginwindow ≥ vài giờ không UI, **When** soft lock fail, **Then** skill/agent **bắt buộc** hướng dẫn Log Out (không hứa soft-fix), và sau login lại SI=off.
4. **Given** API khóa cũ (`CGSession`) thiếu trên OS, **When** chạy script lock, **Then** dùng `SACLockScreenImmediate` và không fail im lặng.

---

### User Story 2 — Barrier bàn phím sang Windows (Priority: P1)

User dùng Barrier (Mac = server). Chuột sang Win OK, gõ phím không được.

**Why this priority**: Cùng root cause SI; đây là lý do user báo “chưa ổn” sau khi nghĩ đã fix.

**Independent Test**: `fix-barrier-keyboard` — nếu SI on → exit 2 + hướng dẫn; nếu SI off → restart Barrier → gõ được sang Win.

**Acceptance Scenarios**:

1. **Given** SI=on, **When** `fix-barrier-keyboard`, **Then** báo BLOCKED, không giả vờ restart sẽ chữa.
2. **Given** SI=off, **When** `fix-barrier-keyboard`, **Then** `barriers` chạy lại và phím tới client Win.
3. **Given** SI vừa nhả, **When** user chạy `fix-barrier-keyboard`, **Then** không cần Restart Mac.

---

### User Story 3 — Watchdog phát hiện sớm (Priority: P2)

SI kẹt ≥ 90s → notify + auto-lock thay vì để 16 giờ.

**Why this priority**: Giảm thời gian “không biết vì sao”.

**Independent Test**: LaunchAgent loaded; giả lập state file cùng PID > 90s → gọi lock path.

**Acceptance Scenarios**:

1. **Given** watchdog installed, **When** SI cùng PID ≥ 90s, **Then** notification + `SACLockScreenImmediate` (có cooldown).
2. **Given** SI=off, **When** tick watchdog, **Then** xóa state, không lock.

---

### User Story 4 — Gõ tiếng Việt ổn định (Priority: P2)

User ưu tiên Telex hệ thống; EVKey optional.

**Acceptance Scenarios**:

1. **Given** Telex bật, SI=off, **When** gõ trong TextEdit, **Then** dấu tiếng Việt OK.
2. **Given** user vẫn dùng EVKey, **When** `fix-go-tieng-viet --evkey`, **Then** EVKey restart có kiểm soát.

---

### User Story 5 — Giảm nguồn gây SI / tranh tap (Priority: P3)

AnyDesk không tự chạy lúc boot (đã làm). Lightshot/iTerm Secure Keyboard Entry được nhắc trong diagnose.

**Acceptance Scenarios**:

1. **Given** AnyDesk plists Disabled, **When** reboot, **Then** AnyDesk không tự start (verify).
2. **Given** diagnose, **When** iTerm/Lightshot chạy, **Then** CAUSE_* nêu rủi ro đúng mức.

## Requirements *(mandatory)*

### Functional

- **FR-001**: `diagnose.sh` MUST báo PID/COMM/ETIME/KIND của Secure Input holder.
- **FR-002**: Mọi đường khóa màn hình MUST dùng `SACLockScreenImmediate` (fallback Ctrl+Cmd+Q AppleScript).
- **FR-003**: `fix-barrier-keyboard` MUST refuse “fake fix” khi SI=on.
- **FR-004**: Khi loginwindow giữ SI với ETIME lớn và không UI, agent MUST recommend Log Out trước Restart.
- **FR-005**: CONTEXT.md MUST được cập nhật khi có phát hiện mới về nhả SI.
- **FR-006**: Watchdog MUST NOT sửa `defaults` screensaver / `pmset` trừ khi user yêu cầu rõ.

### Non-goals

- Không tắt Secure Input toàn cục.
- Không disable SIP / inject vào loginwindow.
- Không thay thế Barrier bằng KVM phần cứng trong scope này (chỉ document là option).

## Success Criteria

| ID | Criterion |
|----|-----------|
| SC-001 | Sau Log Out + login, `IsSecureEventInputEnabled=0` và Barrier gõ được sang Win |
| SC-002 | Soft path (lock+password) hoạt động trên macOS hiện tại khi SI chưa “deep stuck” |
| SC-003 | Không còn script phụ thuộc `CGSession` path đã chết |
| SC-004 | User có workspace Speckit riêng để iterate không mất context chat |

## Assumptions

- Mac là Barrier **server**; Win là client.
- User chấp nhận Log Out như bước nặng hơn lock, nhẹ hơn Restart đầy đủ.
- Quyền Accessibility cho Barrier đã được cấp (nếu chưa, SI=off vẫn có thể fail phím — diagnose cần nói rõ nếu phát hiện sau này).

## Open Questions / Risks

1. Có cách nào nhả loginwindow SI deep-stuck **không** Log Out trên macOS version này không? (Hiện: chưa tìm thấy.)
2. Touch ID unlock có tái tạo nest count không — cần test có kiểm soát.
3. Cursor (Electron) có thể cướp SI tạm (đã thấy PID nhảy sang Cursor rồi về loginwindow).
