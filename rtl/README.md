# rtl/

只放**可合成**的 Verilog。每個子系統一個資料夾，每個資料夾裡有自己的 `README.md`（用 `docs/templates/SUBSYSTEM_README.md` 當模板）。

| 資料夾 | 前綴 | 內容 | 負責人 |
|---|---|---|---|
| `top/` | `pet_` | `pet_top.v`，把所有子系統接起來 | 整合者 |
| `ctrl/` | `ctrl_` | 重置同步、heartbeat、之後的模式狀態機 | 整合者（模式狀態機另定） |
| `camera/` | `cam_` | 相機介面與擷取 | TBD |
| `vision/` | `vis_` | 背景相減、質心追蹤、規則式猜拳 | TBD |
| `cnn/` | `cnn_` | 小型 CNN 推論硬體 | 整合者／CNN 負責人 |
| `hdmi/` | `hdmi_` | HDMI 輸出與 HUD | TBD |
| `servo/` | `srv_` | 雲台與手臂的 PWM 控制 | TBD |
| `bluetooth/` | `bt_` | 藍牙 UART 與手機指令 | TBD |

規則重點：一檔一模組、檔名＝模組名、埠名 `_i/_o`、單一時脈 `clk_i`、同步低電位有效 `rst_n_i`。完整規則見根目錄 `README.md` 與 `docs/AI_RULES.md`。

新增或刪除檔案後，記得在 Vivado Tcl Console 重新執行 `source <repo>/scripts/create_project.tcl`，專案才會同步。
