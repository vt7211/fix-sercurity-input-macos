# kiem-tra-go-tieng-viet

Cursor **Agent Skill** + dự án **Speckit** trên macOS — chẩn đoán và xử lý lỗi bàn phím liên quan:

| Lớp | Triệu chứng | Hướng xử lý |
|-----|-------------|-------------|
| **A — Secure Input** | EVKey chết; Barrier chuột OK nhưng **phím → Windows** chết; SI kẹt `loginwindow` không UI | `nha-secure-input` → Log Out nếu deep-stuck |
| **B — Barrier remap** | SI=off nhưng mất chữ trên Mac (`a`/`s`/`v`/`c`/`x`…) | Comment `keystroke(Super\|Meta+chữ)` trong `~/barrier.conf` |

**Host tham chiếu:** IMac.local / vt7211 · Barrier server → Windows · gõ VN bằng **Telex** hệ thống (EVKey optional).

**Speckit feature:** `001-secure-input-release` — **COMPLETE** (2026-10-17). Xem [SUCCESS-CRITERIA.md](specs/001-secure-input-release/SUCCESS-CRITERIA.md).

---

## Mở workspace

```bash
open ~/.cursor/skills/kiem-tra-go-tieng-viet/kiem-tra-go-tieng-viet.code-workspace
```

Agent: đọc `SKILL.md` trước khi sửa lỗi lâu dài. Bộ nhớ sự cố: `CONTEXT.md`.

---

## Cấu trúc thư mục

```text
kiem-tra-go-tieng-viet/
├── SKILL.md                 # Hướng dẫn agent (entry skill)
├── CONTEXT.md               # Lịch sử sự cố + quyết định đã chốt
├── REFERENCE.md             # Lệnh / API (SACLock, ioreg, watchdog)
├── CHECKLIST-NHA-SI.md      # Checklist vận hành (Log Out path + remap)
├── README.md                # File này
├── kiem-tra-go-tieng-viet.code-workspace
├── scripts/                 # Công cụ CLI
├── specs/001-secure-input-release/   # Speckit feature
│   ├── spec.md
│   ├── plan.md
│   ├── tasks.md
│   ├── SUCCESS-CRITERIA.md
│   ├── KEYBOARD-GRABBER-ABTEST.md    # A/B: Barrier remap = root cause chữ
│   └── ANALYSIS.md
├── .specify/                # Speckit (constitution, templates, scripts)
└── .cursor/skills/speckit-* # Slash-skills Speckit cho Cursor
```

---

## Cài symlink + watchdog (một lần)

```bash
bash ~/.cursor/skills/kiem-tra-go-tieng-viet/scripts/install-secure-input-watchdog.sh
```

Tạo/ cập nhật:

| Symlink (`~/.local/bin/`) | Script |
|---------------------------|--------|
| `diagnose-go-tieng-viet` | `scripts/diagnose.sh` |
| `nha-secure-input` | `scripts/nha-secure-input.sh` |
| `fix-go-tieng-viet` | `scripts/fix-nhanh.sh` |
| `fix-barrier-keyboard` | `scripts/fix-barrier-keyboard.sh` |
| `fix-keyboard-grabbers` | `scripts/fix-keyboard-grabbers.sh` |

LaunchAgent: `com.user.secure-input-watchdog` (30s; SI cùng PID ≥90s → auto-lock; grace sau unlock).

---

## Lệnh nhanh

```bash
# Chẩn đoán (luôn chạy trước)
diagnose-go-tieng-viet

# Lớp A — nhả Secure Input
nha-secure-input              # khóa màn hình; mở bằng MẬT KHẨU (tránh Touch ID)
nha-secure-input --check      # chỉ kiểm tra SI
# loginwindow kẹt lâu / không UI → Apple menu → Log Out (không Restart)

# Barrier sau khi SI = off
fix-barrier-keyboard
fix-barrier-keyboard --wait   # poll SI tắt rồi restart Barrier

# Lớp B — mất chữ trên Mac (SI đã off)
fix-keyboard-grabbers        # báo cáo + soft
fix-keyboard-grabbers --stop # ưu tiên quit Barrier (+ grabber khác)
fix-keyboard-grabbers --restore

# Soft fix gõ VN (Telex ưu tiên; EVKey tùy chọn)
fix-go-tieng-viet
fix-go-tieng-viet --lock
fix-go-tieng-viet --evkey
```

Regression lock API:

```bash
bash scripts/check-lock-api.sh
bash scripts/validate-watchdog-state.sh --self-test
```

---

## Quyết định đã chốt (đừng đảo)

1. **Khóa màn hình:** chỉ `SACLockScreenImmediate` — **không** dùng path `CGSession` (đã chết trên macOS này).
2. **Deep-stuck SI (`loginwindow` nhiều giờ, không UI):** Log Out; không hứa soft-fix / không inject loginwindow.
3. **Gõ VN ổn định:** VietnameseIM **Telex**; EVKey không bắt buộc.
4. **`~/barrier.conf`:** mọi `keystroke(Super|Meta+chữ) = …` phải **comment**. Bật lại → mất đúng chữ đó trên Mac.  
   Backup gốc: `~/barrier.conf.bak-asv-20261017`.  
   Sang Windows: dùng **Ctrl** (Cmd không còn map qua Barrier).
5. AnyDesk autostart trên host này: đã Disabled / `RunAtLoad=false`.

Chi tiết dài: [CONTEXT.md](CONTEXT.md) · A/B: [KEYBOARD-GRABBER-ABTEST.md](specs/001-secure-input-release/KEYBOARD-GRABBER-ABTEST.md).

---

## Scripts

| Script | Vai trò |
|--------|---------|
| `diagnose.sh` | Rank `CAUSE_*` (SI, Barrier, Logi, ChromeRD, remap conf, …) |
| `nha-secure-input.sh` | Nhả SI qua lock màn hình |
| `fix-barrier-keyboard.sh` | SI on → từ chối fake-fix; SI off → restart Barrier |
| `fix-keyboard-grabbers.sh` | SI=off mất chữ — report / `--stop` / `--restore` |
| `fix-nhanh.sh` | Soft fix VN (+ `--lock` / `--evkey`) |
| `secure-input-watchdog.sh` | LaunchAgent tick |
| `install-secure-input-watchdog.sh` | Cài plist + symlink |
| `check-lock-api.sh` | Đảm bảo không phụ thuộc CGSession |
| `validate-watchdog-state.sh` | Schema state JSON |

---

## Speckit

| Mục | Giá trị |
|-----|---------|
| Integration | `cursor-agent` |
| Feature | `specs/001-secure-input-release` |
| Short name | `secure-input-release` |
| Constitution | `.specify/memory/constitution.md` |
| Status | **COMPLETE** (Phase 0–5, SC-001 PASS `win-ok`) |

Slash skills trong `.cursor/skills/speckit-*` (`specify`, `plan`, `tasks`, `implement`, `analyze`, …).

Optional còn lại (không chặn đóng feature): Touch ID vs password nest-count; flag `SECURE_INPUT_DEEP_STUCK` — xem [plan.md](specs/001-secure-input-release/plan.md).

---

## Phân nhánh khi user báo lỗi

```text
diagnose-go-tieng-viet
        │
        ├─ SECURE_INPUT_ACTIVE=yes ──► nha-secure-input
        │         └─ vẫn on + loginwindow lâu ──► Log Out
        │
        ├─ SI=off + mất chữ Mac ──► xem BARRIER_CONF_ACTIVE_LETTER_REMAPS
        │         └─ hoặc fix-keyboard-grabbers --stop
        │
        └─ SI=off + chỉ phím Win hỏng ──► fix-barrier-keyboard
```

Checklist tay: [CHECKLIST-NHA-SI.md](CHECKLIST-NHA-SI.md).
