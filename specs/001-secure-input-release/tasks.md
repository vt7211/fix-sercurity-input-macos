# Tasks: 001-secure-input-release

## Phase 0 — Bootstrap (done)

- [x] T001 Init Speckit (`specify init --here --integration cursor-agent`)
- [x] T002 Constitution + CONTEXT + REFERENCE + SKILL
- [x] T003 Baseline spec/plan
- [x] T004 Scripts: nha-secure-input, watchdog, fix-barrier-keyboard, SACLock
- [x] T005 Disable AnyDesk RunAtLoad (host)
- [x] T006 Open Finder + Cursor workspace

## Phase 1 — Diagnose accuracy (P1)

- [x] T010 `diagnose.sh`: nếu KIND=login và ETIME ≥ 30m → CAUSE hint **Log Out bắt buộc nếu lock fail**
- [x] T011 `diagnose.sh`: detect Barrier running + SI on → CAUSE `barrier_blocked_by_secure_input` HIGH
- [x] T012 Self-check: `scripts/check-lock-api.sh` fail nếu chỉ còn CGSession

## Phase 2 — Release UX (P1)

- [x] T020 `nha-secure-input`: sau lock, in rõ “mở bằng mật khẩu; rồi chạy fix-barrier-keyboard”
- [x] T021 `fix-barrier-keyboard`: khi SI clears mid-wait (optional poll flag `--wait`)
- [x] T022 One-pager `CHECKLIST-NHA-SI.md` (Log Out path)

## Phase 3 — Watchdog harden (P2)

- [x] T030 Không auto-lock nếu vừa unlock < N giây (tránh loop)
- [x] T031 Khi SI chuyển off → optional `open -a Barrier` nếu barriers chết
- [x] T032 Unit-ish: state file JSON schema

## Phase 4 — Docs / Speckit close (P2)

- [x] T040 `/speckit-analyze` consistency → [ANALYSIS.md](./ANALYSIS.md)
- [x] T041 Cập nhật CONTEXT sau mỗi incident thật
- [x] T042 Đánh dấu SC-001…SC-004 pass/fail → [SUCCESS-CRITERIA.md](./SUCCESS-CRITERIA.md)

## Phase 5 — Post-incident: mất chữ khi SI=off (P0, 2026-10-17)

- [x] T050 A/B isolate grabbers → thủ phạm Barrier ([KEYBOARD-GRABBER-ABTEST.md](./KEYBOARD-GRABBER-ABTEST.md))
- [x] T051 Root cause: `barrier.conf` Super/Meta letter remaps; disable all; user confirm `asv`+`cxz` OK
- [x] T052 `fix-keyboard-grabbers.sh` + diagnose codes + CONTEXT/SKILL/REFERENCE sync
- [x] T053 User confirm Barrier phím → Windows OK (đóng SC-001) — 2026-10-17 ~12:51 `win-ok`
