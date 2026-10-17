# Implementation Plan: Secure Input Release & Barrier Keyboard

**Spec**: [spec.md](./spec.md)  
**Date**: 2026-10-17  
**Status**: **COMPLETE** (Phase 0–5, SC-001 PASS — user `win-ok` 2026-10-17 ~12:51).

## Current baseline (already in tree)

- [x] `diagnose.sh` ranking (+ login ETIME → Log Out hint; `barrier_blocked_by_secure_input`; grabbers; barrier conf remap warn)
- [x] `nha-secure-input.sh` + `SACLockScreenImmediate` + post-lock UX
- [x] `fix-barrier-keyboard.sh` (+ `--wait` poll)
- [x] `fix-keyboard-grabbers.sh` (SI=off mất chữ)
- [x] Watchdog LaunchAgent (grace, skip if screen locked, reopen Barrier, state schema)
- [x] AnyDesk RunAtLoad disabled (host)
- [x] CONTEXT / REFERENCE / constitution / SKILL / CHECKLIST-NHA-SI
- [x] Barrier conf: disable all Super/Meta letter keystroke maps (A/B proven)
- [x] Deep-stuck guidance (diagnose HIGH + checklist; no force Log Out)
- [ ] Controlled test: Touch ID vs password unlock nest count (optional P3)
- [ ] Document Accessibility check for Barrier when SI=off but keys still fail (optional)

## Optional follow-ups (not blocking close)

1. **P2** — `SECURE_INPUT_DEEP_STUCK=yes` machine-readable flag.
2. **P2** — AppleScript “Log Out” with user confirm (never force).
3. **P3** — Touch ID vs password nest-count test.

## Tech notes

- Do not reintroduce CGSession path.
- Do not re-enable `keystroke(Super|Meta+letter)` in `~/barrier.conf` on this host.
- Do not change screensaver defaults / pmset unless user asks.
- Keep Telex as recommended VN input; EVKey optional.
