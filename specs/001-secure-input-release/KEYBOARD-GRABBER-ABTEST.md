# A/B test — app nào làm mất chữ (SI=off)

**Ngày**: 2026-10-17  
**Máy**: vt7211 / IMac.local  
**Baseline**: sau `fix-keyboard-grabbers --stop`, user gõ được chữ thường.

Phương pháp: mỗi lần **chỉ 1 app ON**, các app còn lại OFF. User gõ `asv123` trong Cursor trên Mac.

| # | App only ON | Kết quả | Ghi chú |
|---|-------------|---------|---------|
| 0 | (không app) | **OK** | Baseline đã confirm |
| 1 | Logi Options (`LogiMgrDaemon`) | **OK** | Không phải thủ phạm |
| 2 | Barrier (`barriers`) + conf cũ | **FAIL** | Mất chữ trên Mac |
| 2b | Barrier + conf **đã tắt remap a/s/v** | **OK** | Root cause hẹp |
| 3 | Chrome Remote Desktop host | skipped | |
| 4 | Lightshot | skipped | |

## Kết luận

**App:** Barrier — nhưng lỗi không phải “Barrier luôn hỏng”, mà do config.

**Root cause:** `~/barrier.conf` các dòng:

```text
keystroke(Super|Meta + a) = keystroke(Control+a)
keystroke(Super|Meta + s) = keystroke(Control+s)
keystroke(Super|Meta + v) = keystroke(Control+v)
```

Trên Mac primary, remap này làm mất/nuốt phím `a`/`s`/`v` (triệu chứng user báo).

**Fix đã áp dụng (giữ):** comment **toàn bộ** `keystroke(Super|Meta+…)` trong options (`DISABLED-ASV-TEST` + `DISABLED-ALL-MODMAP`).  
Sau khi chỉ tắt a/s/v, user vẫn lỗi `c`/`x` → confirm mọi remap chữ đều hại primary Mac.  
**Backup:** `~/barrier.conf.bak-asv-20261017`

### Verify

- Barrier off → OK  
- Barrier on + remap a/s/v tắt → OK (12:43); vẫn lỗi c/x  
- Barrier on + **tắt hết** Super/Meta keystroke map → **cxz OK** (12:46)

### Lưu ý

- Sang Windows: Cmd+C/V/X/A/Z/S **không** còn map sang Ctrl qua Barrier. Dùng Ctrl bên Win.
- **Không** bật lại các dòng `keystroke(Super|Meta+…)` trong `~/barrier.conf` — sẽ làm mất đúng các chữ đó trên Mac.
- Escape: `fix-keyboard-grabbers --stop`. Backup gốc: `~/barrier.conf.bak-asv-20261017`.
