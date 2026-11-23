# hw_tests/ssd1306_oled — 0.96 吋 I2C OLED 相容性測試

獨立的硬體測試，**不屬於 `guardian_top`**，`scripts/check.tcl` 與
`scripts/create_project.tcl` 不會讀這個資料夾。

| 檔案 | 內容 |
|---|---|
| `rtl/ssd1306_i2c_master.v` | 只寫（write-only）I2C 位元組主控端，開汲極（open-drain）輸出，約 100 kHz |
| `rtl/ssd1306_oled_test_top.v` | 測試頂層：SSD1306 初始化、文字頁（含邊框、計數器、進度條）、棋盤格頁、NACK 偵測 |
| `constr/ssd1306_oled_test.xdc` | 腳位：OLED 接 Arduino 排座的 `SCL` / `SDA` 腳（實測 SCL = P15、SDA = P16） |
| `sim/ssd1306_oled_test_tb.v` | 自我檢查測試平台（含 SSD1306 I2C 從端行為模型） |
| `build.tcl` | 非專案模式建置，輸出 `build/ssd1306_oled_test/ssd1306_oled_test.bit` |

## 模組（依使用者照片判斷）

- 藍色 PCB，4 腳，絲印順序 `GND VCC SCL SDA`，背面 "0.96 OLED IIC"。
- 背面 "IIC ADRESS SELECT 0x78 / 0x7A"，電阻焊在 0x78 那側 → 7-bit 位址 **0x3C**
  （0x78 是含寫入位元的 8-bit 寫法）。若電阻在 0x7A 側，把頂層參數
  `I2C_ADDR` 改成 `7'h3D`。
- 控制晶片推測為 **SSD1306、128x64**（未經證實；0.96 吋 I2C 模組幾乎都是這顆）。
  若畫面只亮一半或錯位，可能是 SH1106 或 128x32，見「疑難排解」。
- 板上有穩壓 IC（U2），VCC 可接 3.3 V。

## 安全原則

1. **OLED 的 VCC 接 PYNQ-Z2 的 3.3V，不接 5V。** 模組自帶的 SCL/SDA 上拉電阻接在
   它自己的電源上，用 3.3 V 供電時，SCL/SDA 最高只會到 3.3 V，FPGA 腳位安全。
2. FPGA 只會把 SCL/SDA 拉到 0 或放開（高阻抗 Z），**永遠不會主動輸出 1**
   （開汲極），所以就算接線短路到 GND 也不會有大電流。XDC 另外開啟 FPGA 內部上拉。
3. 接線、拔線都在**斷電**時做。

## 接線（板子先斷電）

需要 4 條**公母杜邦線**：母頭插 OLED 的針腳，公頭插 PYNQ-Z2 的母座。

| OLED 腳位（絲印） | 接到 PYNQ-Z2 | 位置說明 | FPGA 腳 |
|---|---|---|---|
| GND | Arduino 電源排座 `GND` | 板子邊緣的電源排座（有 `3V3`/`3.3V`、`5V`、`GND`、`VIN` 字樣） | — |
| VCC | Arduino 電源排座 **`3V3`（3.3V）** | 同上，**不是 `5V`** | — |
| SCL | Arduino 數位排座 `SCL` | 10 腳數位排座的最末端：AR8…AR13、GND、AREF、**SDA**、**SCL** | P15（實測） |
| SDA | Arduino 數位排座 `SDA` | 緊鄰 SCL | P16（實測） |

**注意**：課程的 `PYNQ-Z2 v1.0.xdc` 寫 `ar_scl = P16`、`ar_sda = P15`，但實測照絲印接線時，要把兩者對調（SCL = P15、SDA = P16）OLED 才會回應，見「實測紀錄」。尚未對照 PYNQ-Z2 電路圖確認是 XDC 標錯還是當時接線交叉；主專案若要用這兩支腳，以本測試的 XDC 為準。

說明：
- 數位排座就是 LCD 測試用到 AR8–AR13 的那一排；順著 AR13 往外數是 GND、AREF、
  SDA、SCL（Arduino UNO R3 的標準排列）。**插線前請看板上絲印確認 `SDA`、`SCL`
  字樣**；我沒有親眼看過這塊板子的絲印，以實物為準。
- 若找不到 SCL/SDA 字樣，先不要接，回報後改用其他空腳（例如 AR2/AR3）重新產生 bitstream。
- 不用麵包板也可以；如果用麵包板，GND 與 3.3V 各走一條軌即可。

## 上電前檢查清單

- [ ] 電源開關在 OFF，或 USB 線還沒插
- [ ] OLED `VCC` 那條線插在 **3V3**，不是 5V、不是 VIN
- [ ] OLED `GND` 插在 GND
- [ ] `SCL`、`SDA` 沒有對調（對調不會燒壞，只是不會動）
- [ ] 每條線兩端都插緊；4 條線之間沒有裸露金屬互碰
- [ ] OLED 背面沒有壓在導電物（金屬桌面、螺絲）上
- [ ] LCD 測試的線若還在，不影響（腳位不重疊）

## 預期結果

燒錄後約 0.1 秒內：

- `sw0 = 0`（文字頁）：外圍 1 像素邊框，內容
  ```
   PYNQ-Z2 OLED OK
   SSD1306 128X64
   ADDR 0x3C 100kHz
   UPTIME  0000 s      ← 每秒加 1
   SW0 TEXT/PATTERN
  ███████              ← 進度條，每秒變長，10 秒循環
  ```
- `sw0 = 1`：8x8 棋盤格，每秒黑白反轉一次（檢查每個像素都會亮/暗）
- `btn0`：重新開始（清匯流排、重新初始化、計數歸零）

| LED | 意義 | 正常狀態 |
|---|---|---|
| LED0 | 初始化指令都被 OLED 確認（ACK） | 恆亮 |
| LED1 | 心跳，每秒切換 | 亮 1 秒、暗 1 秒 |
| LED2 | NACK 錯誤：位址沒有裝置回應 | 熄滅 |
| LED3 | 每送完一整個畫面切換一次（約 10 張/秒） | 快速閃爍（約 5 Hz） |

## 診斷功能（2026-11-17 第一次上板 NACK 後加入）

| 項目 | 行為 |
|---|---|
| 自動掃描 | 每次 NACK 後換下一組設定：{腳位正常 / SCL、SDA 對調} × {0x3C / 0x3D}，找到會回應的就固定下來 |
| `sw1 = 1` | 忽略 NACK，固定用「腳位正常 + 0x3C」照樣送畫面（給不回 ACK 的模組） |
| START 前檢查 | 送 START 前兩條線都必須是高電位，否則當成錯誤（LED2 亮）並重試 |
| RGB LD4 | 線路電位：綠 = 兩條都是高（上拉正常）；紅 = P15（SCL）被拉低；藍 = P16（SDA）被拉低（LED 跟著 XDC 的 SCL/SDA 角色） |
| RGB LD5 | 找到的設定：綠 = 正常 0x3C；藍 = 正常 0x3D；黃 = 對調 0x3C；洋紅 = 對調 0x3D；暗 = 還沒有回應 |

模擬：一般情況加上「線對調」「位址 0x3D」「兩者皆是」共 4 種，全部 PASS。
建置：WNS = +2.683 ns，0 個 critical warning。

## 疑難排解

| 現象 | 判斷 | 處理 |
|---|---|---|
| LED 全暗、LED1 也不閃 | FPGA 沒有被燒錄 | 重新燒錄；確認電源跳線與電源 |
| LED2 亮、LED0 暗 | **沒有 ACK**：OLED 沒回應 | 斷電；檢查 VCC/GND 是否接上、SCL/SDA 是否對調、是否插到正確排座；位址電阻若在 0x7A 側要改 `I2C_ADDR` |
| LED0 亮、LED3 閃，但螢幕全黑 | **有 ACK 但不顯示**：通訊正常 | 確認 VCC 是 3.3V（太低時充電泵不足）；按 btn0 重來；回報以便調整初始化指令 |
| 畫面只有上半或每隔一行 | 可能是 128x32 面板，或 COM 腳設定不同 | 回報，改 `A8`/`DA` 參數 |
| 畫面左右偏移 2 像素、右邊有雜點 | 可能是 SH1106（不支援水平定址） | 回報，改用分頁定址模式 |
| 文字上下左右顛倒 | 方向設定 | 改 `A1`→`A0`、`C8`→`C0` |

## 模擬與建置

- 模擬（Vivado 2019.2 xsim 批次模式）：`RESULT: PASS (frames=10, nack_stops=3)`
  ```
  xvlog.bat rtl/ssd1306_i2c_master.v rtl/ssd1306_oled_test_top.v sim/ssd1306_oled_test_tb.v
  xelab.bat -timescale 1ns/1ps ssd1306_oled_test_tb -s tb_snap
  xsim.bat tb_snap -runall
  ```
  檢查項目：26 個初始化指令、匯流排沒有 X（沒有主動輸出 1）、SCL 高/低時間、
  START/STOP 只出現在位元組邊界、每張畫面 1024 bytes、字型與邊框、計數器會變、
  棋盤格、NACK 時 LED2 亮且送出 STOP、恢復後 LED0 亮、btn0 中途重置後能恢復。
- 建置：`vivado.bat -mode batch -source hw_tests/ssd1306_oled/build.tcl`
  （2026-11-17：WNS = +2.934 ns，0 個 critical warning，377 LUT / 207 FF）
- 像素位元組（字型查表）用 4 級暫存器管線計算，每個位元組送出前等 7 個時脈；
  第一版純組合邏輯 WNS = −3.373 ns，管線化後通過。

## 實測紀錄

### 2026-11-17：成功

- 接線：照上方表格（OLED VCC → 3V3、GND → GND、SCL → 排座絲印 SCL、SDA → 排座絲印 SDA），
  用公母杜邦線直接插，沒有外加電阻。
- 第一版 bitstream（XDC：SCL = P16、SDA = P15，照課程 XDC）：LD1 閃、LD2 亮（NACK），螢幕全黑。
- 診斷版 bitstream（同樣腳位，加自動掃描）：LD0 恆亮、LD2 滅、LD3 快閃，螢幕正常顯示，
  sw0 切換文字頁與棋盤格都正常 → 控制晶片的行為與 SSD1306 128x64 一致。
  LD5 是「綠 + 一點紅」= 黃色 = **SCL/SDA 對調、位址 0x3C**；把 sw1 撥上（強制腳位正常）時
  畫面凍結，證實正常腳位不通。
- **原因：SCL 與 SDA 的 FPGA 腳位相對於課程 XDC 對調。** 已把 XDC 改成 SCL = P15、SDA = P16
  （WNS = +2.681 ns）。改完後實測：sw1 關時 LD5 純綠（腳位正常、0x3C），
  sw1 開時畫面持續更新，不再凍結。
- 斷電重開後重新燒錄，仍能自動找到 OLED（LD2 未亮）。
- RGB LD4/LD5 亮度不穩、偶爾突然變亮：PWM 頻率 15.6 MHz 太高，可能是 LED 驅動電路
  跟不上（推測，未證實），不影響功能。
