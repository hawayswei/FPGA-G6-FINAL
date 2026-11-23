# hw_tests/lcd1602 — 1602A 字元 LCD 相容性測試

獨立的硬體測試，**不屬於 `guardian_top`**，`scripts/check.tcl` 與
`scripts/create_project.tcl` 不會讀這個資料夾。

| 檔案 | 內容 |
|---|---|
| `rtl/lcd1602_driver.v` | HD44780 4-bit、只寫（write-only）位元組驅動 |
| `rtl/lcd1602_test_top.v` | 測試頂層：初始化、自訂字元（愛心、笑臉）、兩個頁面 |
| `constr/lcd1602_test.xdc` | 腳位：LCD 接 Arduino 排座 AR8–AR13 |
| `sim/lcd1602_test_tb.v` | 自我檢查測試平台（含 HD44780 行為模型） |
| `build.tcl` | 非專案模式建置，輸出 `build/lcd1602_test/lcd1602_test.bit` |

## 接線（板子先斷電）

LCD 的 RW 一定要接 GND：這樣 LCD 只接收、不會把 5 V 送回 FPGA 的 3.3 V 腳位。

| LCD 腳位（絲印） | 接到 | 說明 |
|---|---|---|
| 1 VSS | 麵包板 GND 軌 | 電源地 |
| 2 VDD | 麵包板 5V 軌 | 邏輯電源 5 V |
| 3 V0 | 串 5.6 kΩ 到麵包板 GND 軌 | 對比度，見下方「對比度電阻」 |
| 4 RS | AR8 | |
| 5 RW | 麵包板 GND 軌 | **必接 GND** |
| 6 E | AR9 | |
| 7–10 D0–D3 | 不接 | 4-bit 模式用不到 |
| 11 D4 | AR10 | |
| 12 D5 | AR11 | |
| 13 D6 | AR12 | |
| 14 D7 | AR13 | |
| 15 A | 麵包板 5V 軌 | 背光正極 |
| 16 K | 麵包板 GND 軌 | 背光負極 |

麵包板 5V 軌 ← PYNQ-Z2 Arduino 電源排座 `5V`；GND 軌 ← 同排座 `GND`。

## 對比度電阻（2026-11-17 實測）

V0 接在一顆電阻到 GND；電阻越大，V0 越高，畫面越淡。

| V0 到 GND | 結果 |
|---|---|
| 0 Ω（直接接地） | 太深，每格都是方塊，要斜著看 |
| 1.6 kΩ | 仍偏深 |
| 3.6 kΩ（1.6 k + 2.0 k 串聯） | 清楚 |
| **5.6 kΩ（1.6 k + 2.0 k + 2.0 k 串聯）** | **最終採用** |

色環：1.6 kΩ = 棕藍紅金，2.0 kΩ = 紅黑紅金。
V0 不可接 3.3 V（對比會消失，且 5 V 會經 LCD 內部分壓電阻灌進 3.3 V 電源）。

## 預期結果

- `sw0 = 0`：第 1 行 `PYNQ-Z2 + 1602A`，第 2 行 `♥ OK ☺  T=0000s`（秒數遞增）
- `sw0 = 1`：第 1 行 `Are you OK?   ♥☺`，第 2 行 `Cancel in: 10 s`（10 倒數到 0 循環）
- `btn0`：重新初始化 LCD、計數歸零
- LED0 = 第一次畫面寫完；LED1 = 每秒切換；LED2 = 頁面；LED3 = btn0 按下

## 模擬與建置

- 模擬（xsim 批次模式）：`RESULT: PASS`
- 建置：`vivado.bat -mode batch -source hw_tests/lcd1602/build.tcl`
