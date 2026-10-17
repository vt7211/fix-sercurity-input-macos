# CONTEXT — Secure Input / Gõ tiếng Việt / Barrier

Cập nhật: 2026-10-17 ~12:51 (Speckit **COMPLETE** — SC-001 win-ok). Đây là bộ nhớ bền cho skill; đọc trước khi sửa script.

## Vấn đề cốt lõi (P0)

**Hai lớp lỗi bàn phím** (đừng gộp một):

### A) Secure Input kẹt (`loginwindow`, đã ghi nhận ~16–17h, không UI)

1. Không gõ được tiếng Việt qua EVKey (CGEventTap bị chặn).
2. **Barrier không gửi bàn phím sang Windows** (chuột vẫn được).
3. Soft lock fail → **Log Out** (không Restart nếu tránh được).

### B) SI=off nhưng mất chữ thường trên Mac — 2026-10-17 (ĐÃ CHỐT)

**Không phải Secure Input.** A/B: Logi alone=OK; Barrier alone=FAIL.

**Root cause:** `~/barrier.conf` các dòng `keystroke(Super|Meta+chữ) = keystroke(Control+…)` — trên Mac primary làm mất đúng chữ đó (`a/s/v` rồi `c/x`).

**Fix giữ:** comment **toàn bộ** Super/Meta keystroke map trong conf.  
Backup: `~/barrier.conf.bak-asv-20261017`.  
**Không bật lại** các dòng đó. Sang Win dùng Ctrl trực tiếp.  
Escape: `fix-keyboard-grabbers --stop`. Chi tiết: `specs/001-secure-input-release/KEYBOARD-GRABBER-ABTEST.md`.

## Timeline sự cố (máy vt7211)

| Thời điểm | Sự kiện |
|-----------|---------|
| Trước 2026-10 | EVKey hay chết; nghi Accessibility / Logi / iTerm Secure Keyboard Entry |
| 2026-10 (session) | Chẩn đoán: Secure Input PID = Cursor rồi chuyển sang **loginwindow** |
| Cùng session | User chuyển sang **Telex hệ thống** → gõ VN ổn trong app Mac |
| Cùng session | Barrier: chuột OK, phím sang Win fail — cùng root cause Secure Input |
| 2026-10-17 | Tắt AnyDesk autostart (`Frontend` + `service`: Disabled=1, RunAtLoad=0) |
| 2026-10-17 | Cài watchdog `com.user.secure-input-watchdog` (30s / stuck≥90s → auto-lock) |
| 2026-10-17 | Phát hiện **CGSession path không còn** trên macOS này → khóa cũ fail im lặng |
| 2026-10-17 | Chuyển khóa sang `SACLockScreenImmediate`; lock/unlock **vẫn không nhả** SI sau 16h loginwindow |
| 2026-10-17 | Kết luận vận hành: khi SI kẹt lâu bởi loginwindow → **Log Out** (không Restart) |
| 2026-10-17 | Speckit Phase 2: `nha-secure-input` UX, `fix-barrier-keyboard --wait`, `CHECKLIST-NHA-SI.md` |
| 2026-10-17 | Speckit Phase 3: watchdog post-unlock grace 60s, reopen Barrier, state JSON schema |
| 2026-10-17 ~12:30 | Incident tiếp: SI vẫn ON — `loginwindow` PID **30191**, ETIME ~**17h** (1040 phút), không dialog; Barrier `barriers` chạy nhưng phím Win bị chặn. Soft path không đủ → **Log Out** |
| 2026-10-17 ~12:35 | Sau Log Out: SI=off, Telex selected. User báo phím thiếu ký tự. Restart Barrier. Suspect phụ: LogiMgrDaemon + Lightshot (CGEventTap) |
| 2026-10-17 ~12:38 | User: không gõ được cả `a`/`s`/`v` trên Mac (SI=off). Stop Lightshot + U.S. + Barrier + ChromeRD + bootout `com.logitech.manager.daemon` |
| 2026-10-17 ~12:39 | User confirm: **đã gõ được chữ lại**. Ghi nhận pattern B + script `fix-keyboard-grabbers.sh` |
| 2026-10-17 ~12:41 | A/B: Logi alone=OK; **Barrier alone=FAIL** (mất `a`/`s`/`v` trên Mac). Thủ phạm = **Barrier**. Xem `KEYBOARD-GRABBER-ABTEST.md`. Nghi phụ: `barrier.conf` map Super/Meta+a/s/v → Ctrl+… (modifier kẹt?) |
| 2026-10-17 ~12:42 | Verify: Barrier off → user **OK** gõ lại được |
| 2026-10-17 ~12:43 | Root cause hẹp: `barrier.conf` remap `Super/Meta+a/s/v` → Ctrl. Comment các dòng đó + Barrier ON → user **OK** gõ `asv123`. Backup: `~/barrier.conf.bak-asv-20261017` |
| 2026-10-17 ~12:46 | User: lỗi `c`/`x` → tắt **toàn bộ** Super/Meta keystroke map; restart Barrier → confirm **cxz OK** |
| 2026-10-17 ~12:51 | User **win-ok** — Barrier phím sang Windows OK. SC-001 PASS; feature 001 COMPLETE |

## Root cause kỹ thuật

- Session key: `IOConsoleUsers[].kCGSSessionSecureInputPID`
- Carbon: `EnableSecureEventInput` / `DisableSecureEventInput` — **nest count theo process**
- Process A không thể Disable cho process B
- `loginwindow` giữ SI khi: màn hình khóa, auth, **hoặc bug/state kẹt không UI**
- Touch ID unlock đôi khi **không** giảm nest count (anecdotal / quan sát session này)

## Giải pháp hiện có (trong repo skill)

| Tool | Vai trò |
|------|---------|
| `scripts/diagnose.sh` | Xếp hạng CAUSE_* |
| `scripts/fix-nhanh.sh` | Soft fix; `--lock`; `--evkey` tùy chọn (mặc định skip nếu không chạy EVKey) |
| `scripts/nha-secure-input.sh` | Chỉ nhả SI qua lock (`SACLockScreenImmediate`) |
| `scripts/secure-input-watchdog.sh` | LaunchAgent: SI cùng PID ≥90s → auto-lock |
| `scripts/install-secure-input-watchdog.sh` | Cài plist |
| `scripts/fix-barrier-keyboard.sh` | Kiểm SI; nếu off → restart Barrier; nếu on → hướng dẫn |
| `scripts/fix-keyboard-grabbers.sh` | SI=off mà mất chữ: báo cáo / `--stop` / `--restore` |

Symlinks: `~/.local/bin/nha-secure-input`, `fix-go-tieng-viet`, `fix-barrier-keyboard`, `diagnose-go-tieng-viet`, `fix-keyboard-grabbers`.

## Việc Accceptable / Không thể làm

| Được | Không được / không khả thi |
|------|----------------------------|
| Diagnose + rank causes | Force-clear SI của loginwindow từ userland |
| Lock → password unlock | “Tắt Secure Input toàn hệ thống” |
| Log Out / Restart | Promise fix vĩnh viễn không đụng session |
| Telex thay EVKey cho gõ VN | Barrier phím khi SI=ON |
| Disable AnyDesk RunAtLoad | |

## Mục tiêu Speckit feature `001-secure-input-release`

1. Nhả SI **không Restart**, ưu tiên không Log Out khi còn có thể.
2. Phát hiện sớm (watchdog) + hướng dẫn rõ khi cần Log Out.
3. Barrier: sau SI=off tự verify/restart server.
4. Tài liệu hóa giới hạn macOS để không “đuổi bóng” Accessibility.
5. Regression: khóa màn hình API phải được test trên macOS version hiện tại.

## Môi trường quan sát (2026-10-17 cuối session)

- Host: IMac.local / user vt7211
- Barrier server: `barriers` listen `192.168.50.189:24800`, crypto off; conf **không** còn Super/Meta letter remap active
- AnyDesk: đã tắt khởi động
- EVKey: không chạy (user dùng Telex)
- SI: sau Log Out = off; holder điển hình khi fail: `loginwindow`
- Speckit `001-secure-input-release`: **COMPLETE** (T053 / SC-001: user win-ok ~12:51)
