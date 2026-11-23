# fall 子系統

| 項目 | 內容 |
|---|---|
| 負責人 | 整合者 |
| 狀態 | 已模擬（`tb_fall_detect` PASS，與 Python 模型逐筆一致）；閾值為暫定值，未用實測資料驗證 |
| 模組前綴 | `fall_` |
| 時脈 | 125 MHz `clk_i` |
| 重置 | 同步、低電位有效 `rst_n_i` |

## 功能

只用三軸加速度判定跌倒：失重 → 時間窗內出現撞擊 → 等 1 秒 → 2 秒內大致靜止 →（可選）姿勢有改變。全部用合成加速度的平方比較，不開平方根。

## 模組清單

| 檔案 | 模組 | 用途 |
|---|---|---|
| `fall_detect.v` | `fall_detect` | 判定狀態機，輸出一個時脈寬的 `fall_o` |
| `fall_param_lut.v` | `fall_param_lut` | 由模式與身高查出失重閾值、撞擊閾值、時間窗 |

電腦端有一份位元一致的模型 `tools/fall_model.py`。**改這裡的邏輯或數值，要同步改那一份**，再執行 `python tools/gen_fall_vectors.py` 並跑 `sim/fall/tb_fall_detect.v`。

## 對外介面（`fall_detect`）

| 埠名 | 方向 | 位寬 | 說明 |
|---|---|---|---|
| `sample_valid_i` | 輸入 | 1 | 每筆取樣一個脈衝（100 Hz） |
| `accel_x_i` `accel_y_i` `accel_z_i` | 輸入 | 各 16（signed） | 加速度，1 g ≈ 250 |
| `lft_sq_i` `uft_sq_i` | 輸入 | 各 24 | 失重、撞擊閾值的平方 |
| `window_i` | 輸入 | 8 | 失重到撞擊允許的取樣數 |
| `posture_en_i` | 輸入 | 1 | 1 = 多要求姿勢改變 |
| `fall_o` | 輸出 | 1 | 判定跌倒的脈衝 |
| `state_o` | 輸出 | 3 | 0 IDLE、1 ARMED、2 SETTLE、3 STILL、4 EVAL |
| `mag_sq_o` `mag_valid_o` | 輸出 | 24、1 | 合成加速度平方，除錯與錄製用 |

## 已知問題 / 待辦

- 所有閾值與時間都是初值，要用 `docs/manual/03-fall-experiment-guide.md` 的實驗資料重新決定。可調項目見 `docs/TUNING.md`。
- 感測器在上臂，日常揮手可能造成誤報；文獻中手腕位置的效果比腰部差，上臂沒有查到數據。
