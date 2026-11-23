# accel 子系統

| 項目 | 內容 |
|---|---|
| 負責人 | 整合者 |
| 狀態 | 已模擬（兩個 testbench PASS）；上板測試待做 |
| 模組前綴 | `acl_` |
| 時脈 | 125 MHz `clk_i`。SCLK 約 0.99 MHz，由計數器產生，不是衍生時脈 |
| 重置 | 同步、低電位有效 `rst_n_i` |

## 功能

透過 SPI 讀取 Pmod ACL2（ADXL362 三軸加速度計）。上電後自動初始化感測器，之後每 10 ms（100 Hz）輸出一組 X、Y、Z 加速度。

## 模組清單

| 檔案 | 模組 | 用途 |
|---|---|---|
| `acl_spi_master.v` | `acl_spi_master` | 一次傳收一個位元組的 SPI master（Mode 0、MSB 先送）。不管 CS |
| `acl_adxl362_ctrl.v` | `acl_adxl362_ctrl` | ADXL362 控制器：軟重置 → 讀裝置 ID → 設定量程與速率 → 進入量測模式 → 週期讀三軸 |

Testbench 在 `sim/accel/`：`tb_acl_spi_master.v`、`tb_acl_adxl362_ctrl.v`（內含 ADXL362 行為模型），跑完會印 `TB PASS` 或 `TB FAIL`。

## 對外介面（`acl_adxl362_ctrl`）

| 埠名 | 方向 | 位寬 | 說明 |
|---|---|---|---|
| `cs_n_o` `sclk_o` `mosi_o` | 輸出 | 各 1 | SPI 腳位，接 Pmod ACL2 |
| `miso_i` | 輸入 | 1 | SPI 資料輸入 |
| `accel_x_o` `accel_y_o` `accel_z_o` | 輸出 | 各 16（signed） | 加速度。三軸在同一個週期一起更新 |
| `data_valid_o` | 輸出 | 1 | 每有一組新資料，拉高一個時脈週期 |
| `dev_ok_o` | 輸出 | 1 | 1 = 讀到裝置 ID `0xAD`，代表接線正確、感測器有回應 |

## 數值怎麼讀

- 預設 `FILTER_CTL_VAL = 0x93`：量程 ±8 g、輸出速率 100 Hz。
- 感測器輸出 12 位元二補數，已符號延伸成 16 位元。±8 g 下 1 LSB 約 4 mg，所以 **1 g 約等於 250**，範圍 −2048 到 +2047。
- 靜止時，朝上的那一軸約 +250，其餘兩軸接近 0。
- 剛啟動的前幾筆資料尚未穩定，使用資料的模組請忽略開機後約 50 ms。

## 參數

| 參數 | 預設 | 說明 |
|---|---|---|
| `HALF_DIV` | 63 | SCLK 半週期的時脈數，SCLK = 125 MHz ÷ (2 × 63)。不可小於 4 |
| `POWERUP_CYCLES` | 2 500 000 | 上電或 ID 錯誤後的等待（20 ms） |
| `RESET_CYCLES` | 1 250 000 | 軟重置後的等待（10 ms） |
| `SAMPLE_CYCLES` | 1 250 000 | 取樣週期（10 ms = 100 Hz） |
| `CS_GAP_CYCLES` | 125 | CS 的建立、保持與間隔時間（1 µs） |
| `FILTER_CTL_VAL` | `8'h93` | 寫入 FILTER_CTL 暫存器的值（量程與速率） |

時間類參數在 testbench 裡會縮短，模擬才跑得快。

## 需要的腳位

Pmod A 上排，見 `constr/acl2.xdc`：CS = Y18、MOSI = Y19、MISO = Y16、SCLK = Y17。INT1、INT2 沒有使用。

## 已知問題 / 待辦

- 暫存器位址與設定值依 ADXL362 資料表撰寫，尚未在實體感測器上驗證。上板後若 `dev_ok_o` 不亮，先查接線，再對照資料表。
- 感測器在運作中掉電再接回，會回到待機狀態並讀到 0。按重置鍵（BTN3）即可重新初始化。
- 沒有使用感測器的 FIFO 與中斷腳。
