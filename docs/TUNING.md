# 調整對照表：想改什麼，去哪裡改

細節（文字、時間、顏色、閾值、按鈕）之後會調整，所以每一項都集中在**一個地方**，改數字或文字就好，不用動邏輯。改完後照最下面的「改完要做的事」檢查。

目前所有數值都是**暫定的初值**，不是實測結果。

## 1. 對照表

| 想改的東西 | 檔案 | 位置 | 目前的值 |
|---|---|---|---|
| 詢問「Are you OK?」的秒數 | `rtl/top/guardian_top.v` | `ASK_SECONDS` | 10 |
| 警報期間重送訊息的間隔 | `rtl/top/guardian_top.v` | `REPEAT_SECONDS` | 5 秒 |
| 長按幾秒算手動求救 | `rtl/top/guardian_top.v` | `LONG_PRESS_CYC` | 2 秒 |
| 藍牙鮑率 | `rtl/top/guardian_top.v` | `UART_CLKS_PER_BIT` | 13021（9600 baud） |
| 送到手機的文字 | `rtl/top/guardian_top.v` | `u_bt_msg` 的 `MSG0`～`MSG7` | FALL、SOS、OK、TEMP HIGH、TEMP LOW、SET、ARE YOU OK? |
| 哪個事件送哪則訊息 | `rtl/top/guardian_top.v` | `u_bt_msg` 的 `.req_i` | 見第 2 節 |
| 手機指令的字母 | `rtl/bluetooth/bt_cmd_parser.v` | `CH_ADULT` 等 localparam | A、E、S、H |
| 身高可接受範圍與預設 | `rtl/bluetooth/bt_cmd_parser.v` | `HEIGHT_MIN`、`HEIGHT_MAX`、`HEIGHT_DEFAULT` | 100～220，預設 170 |
| 各模式的失重／撞擊閾值 | `rtl/fall/fall_param_lut.v` **和** `tools/fall_model.py` 的 `param_lut` | `LFT_*`、`UFT_*` | 成人 0.5 g／2.5 g；老人 0.6／2.0；運動 0.4／3.0 |
| 身高對應的時間窗 | 同上 | `HEIGHT_BAND_*`、`WINDOW_*` | 600～750 ms |
| 失重要持續多久才算 | `rtl/fall/fall_detect.v` **和** `tools/fall_model.py` | `FF_MIN_SAMPLES` | 5 筆（50 ms） |
| 撞擊後等多久才開始看靜止 | 同上 | `SETTLE_SAMPLES` | 100 筆（1 秒） |
| 靜止要看多久、容許幾筆在動 | 同上 | `STILL_SAMPLES`、`STILL_MAX_BAD` | 200 筆（2 秒）、30 筆 |
| 「靜止」的合成加速度範圍 | 同上 | `STILL_LO_SQ`、`STILL_HI_SQ` | 0.8 g～1.2 g |
| 姿勢改變的角度門檻 | 同上 | `POSTURE_DOT_MAX` | 44000（約 45 度） |
| 溫度區間的邊界 | `rtl/temp/tmp_zone.v`（或在 `guardian_top.v` 的 `u_tmp_zone` 覆寫） | `T1`～`T4`、`HYST` | 30、34、37.5、38.5 °C，遲滯 0.5 °C |
| 各溫度區間的顏色與亮度 | 同上 | `COLOR0`～`COLOR4` | 紫、藍、綠、橘、紅 |
| 多久讀一次溫度 | `rtl/temp/tmp_tmp3_reader.v` | `POLL_CYCLES` | 0.25 秒 |
| 加速度計量程與取樣率 | `rtl/accel/acl_adxl362_ctrl.v` | `FILTER_CTL_VAL`、`SAMPLE_CYCLES` | ±8 g、100 Hz |
| 板上 LED 各代表什麼 | `rtl/top/guardian_top.v` | 最下面 `Indicators` 區塊 | 見檔頭註解 |
| 按鈕與開關的功能 | `rtl/top/guardian_top.v` | `u_button` 接的 `btn_i[0]`；`use_test_data`、`posture_en` | BTN0 使用者鍵、BTN3 重置、SW0 假資料、SW1 姿勢檢查 |
| 腳位 | `constr/*.xdc` | 各檔 | 見各檔註解 |
| 假資料的劇本 | `rtl/accel/acl_test_source.v` | `REST_SAMPLES`、`LIE_SAMPLES` 與 always 區塊 | 站 15 秒、失重、撞擊、躺 6 秒 |

單位換算：加速度 1 g ≈ 250；閾值存的是平方，例如 2.5 g → (2.5 × 250)² = 390625。溫度以 0.5 °C 為單位，例如 37.5 °C → 75。取樣 100 Hz，100 筆 = 1 秒。

## 2. 事件與訊息的對應（`guardian_top.v` 的 `.req_i`）

| 位元 | 事件 | 何時發生 | 訊息 |
|---|---|---|---|
| 0 | `ev_fall` | 詢問逾時進入警報；警報中每 5 秒 | `MSG0` FALL |
| 1 | `ev_sos` | 長按求救；警報中每 5 秒 | `MSG1` SOS |
| 2 | `ev_ok` | 詢問中按鈕取消；警報中按鈕解除 | `MSG2` OK |
| 3 | `ev_temp_high` | 溫度升到 37.5 °C 以上的區間 | `MSG3` TEMP HIGH |
| 4 | `ev_temp_low` | 溫度降到 30 °C 以下的區間 | `MSG4` TEMP LOW |
| 5 | `cfg_update` | 手機設定被接受 | `MSG5` SET |
| 6 | `ev_ask` | 偵測到跌倒、開始詢問 | `MSG6` ARE YOU OK? |
| 7 | （未使用） | | `MSG7` 空字串 |

訊息最長 16 個字元，設成空字串 `""` 就不會送。

## 3. 一定要兩邊一起改的地方

`rtl/fall/fall_detect.v`、`rtl/fall/fall_param_lut.v` 和 `tools/fall_model.py` 是同一套演算法的兩份（硬體一份、電腦一份）。統計程式靠電腦那份來預測 FPGA 的判定，所以**兩邊的數值與邏輯必須相同**。

## 4. 改完要做的事

1. 改了 `fall_*` 或 `fall_model.py`：執行 `python tools/gen_fall_vectors.py` 重新產生測試向量，再跑 `tb_fall_detect`，要看到 `TB PASS`。
2. 改了其他模組：跑對應的 testbench（在 `sim/` 下同名資料夾）。
3. 雙擊 `scripts/check.bat`，要看到 PASS。
4. 重新 Generate Bitstream 並上板確認。
5. 改了使用者會看到的行為（文字、按鈕、LED、指令）：同步更新 `docs/manual/02-board-test-guide.md`。

## 5. 還沒做的部分

- OLED 顯示：等確定用哪一種 OLED 再寫。`ctrl_guardian_fsm` 已經輸出 `state_o`、`ask_left_o`（剩餘秒數）、`alarm_sos_o`，`tmp_zone` 輸出 `zone_o`，OLED 模組接這些訊號就能顯示狀態與倒數。
- 所有閾值都要用實測資料重新決定（見 `docs/manual/03-fall-experiment-guide.md`）。
