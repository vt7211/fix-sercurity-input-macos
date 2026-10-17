# Success Criteria — 001-secure-input-release

Đánh giá trên máy vt7211 / IMac.local — chốt 2026-10-17 ~12:51.

| ID | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| SC-001 | Sau Log Out + login, `IsSecureEventInputEnabled=0` và Barrier gõ được sang Win | **PASS** | SI=off. Barrier + conf remap tắt. Mac `asv`/`cxz` OK. User **win-ok** ~12:51. |
| SC-002 | Soft path (lock+password) hoạt động khi SI chưa deep-stuck | **PARTIAL / expected** | `SACLockScreenImmediate` OK. Deep-stuck 16h+ → soft path không đủ (US1.3); Log Out path đã dùng thành công. |
| SC-003 | Không còn script phụ thuộc `CGSession` path đã chết | **PASS** | `check-lock-api.sh` OK. |
| SC-004 | Workspace Speckit riêng, không mất context | **PASS** | workspace + `.specify/` + CONTEXT + Phase 0–5. |

## Live snapshot (chốt)

```text
SECURE_INPUT_ACTIVE=no
BARRIER_RUNNING=yes
barrier.conf Super/Meta letter remaps: all commented
Mac typing: OK | Win typing via Barrier: OK (user win-ok)
```

## Feature status

**001-secure-input-release: COMPLETE** (tasks T001–T053). Optional follow-ups trong plan không chặn đóng feature.
