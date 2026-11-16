# ctrl 子系統

| 項目 | 內容 |
|---|---|
| 負責人 | 整合者 |
| 狀態 | 已模擬（`tb_ctrl_heartbeat`、`tb_ctrl_guardian` PASS）；上板測試待做 |
| 模組前綴 | `ctrl_` |
| 時脈 | 125 MHz `clk_i` |
| 重置 | 同步、低電位有效 `rst_n_i` |

## 功能

重置同步、心跳燈、按鈕處理，以及整個系統的狀態機（監測 → 詢問 10 秒 → 警報鎖存 → 解除）。

## 模組清單

| 檔案 | 模組 | 用途 |
|---|---|---|
| `ctrl_reset_sync.v` | `ctrl_reset_sync` | 把重置按鈕變成同步、低電位有效的 `rst_n` |
| `ctrl_heartbeat.v` | `ctrl_heartbeat` | 約 1 Hz 的心跳訊號 |
| `ctrl_button.v` | `ctrl_button` | 防彈跳；分辨短按（放開時）與長按（按滿時間時） |
| `ctrl_guardian_fsm.v` | `ctrl_guardian_fsm` | 系統狀態機與事件脈衝 |

## 狀態機

| 狀態 | `state_o` | 離開條件 |
|---|---|---|
| MONITOR | 0 | `fall_i` → ASK；長按 → ALARM（求救） |
| ASK | 1 | 短按 → MONITOR；長按 → ALARM（求救）；逾時 → ALARM（跌倒） |
| ALARM | 2 | 短按 → MONITOR。期間每 `REPEAT_SECONDS` 重發一次事件 |

輸出 `ask_left_o`（詢問剩餘秒數）與 `alarm_sos_o`（警報來源）給之後的 OLED 使用。事件脈衝：`ev_ask_o`、`ev_fall_o`、`ev_sos_o`、`ev_ok_o`。

時間參數的修改位置見 `docs/TUNING.md`。
