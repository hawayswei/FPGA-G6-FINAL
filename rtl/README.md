# rtl/

只放**可合成**的 Verilog。每個子系統一個資料夾，每個資料夾裡有自己的 `README.md`（用 `docs/templates/SUBSYSTEM_README.md` 當模板）。

| 資料夾 | 前綴 | 內容 | 負責人 |
|---|---|---|---|
| `top/` | `guardian_` | `guardian_top.v`，把所有子系統接起來 | 整合者 |
| `ctrl/` | `ctrl_` | 重置同步、heartbeat、系統 FSM（詢問 10 秒、ALARM 鎖存）、按鈕處理 | 整合者 |
| `bluetooth/` | `bt_` | 藍牙 UART（9600 8N1）、手機指令與警報回傳 | TBD |
| `accel/` | `acl_` | PmodACL2（ADXL362）SPI 控制器與資料擷取（暫定） | TBD |
| `fall/` | `fall_` | 合成加速度、個人化閾值、跌倒判定（暫定） | TBD |
| `temp/` | `tmp_` | Pmod TMP3 I2C 讀取與溫度區間（暫定） | TBD |
| `oled/` | `oled_` | PmodOLED 文字顯示（暫定） | TBD |

規則重點：一檔一模組、檔名＝模組名、埠名 `_i/_o`、單一時脈 `clk_i`、同步低電位有效 `rst_n_i`。完整規則見根目錄 `README.md` 與 `docs/AI_RULES.md`。

新增或刪除檔案後，記得在 Vivado Tcl Console 重新執行 `source <repo>/scripts/create_project.tcl`，專案才會同步。
