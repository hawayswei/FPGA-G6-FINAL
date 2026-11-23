# tools/

電腦端的 Python 工具。只需要 Python 3.9 以上的標準函式庫；畫圖另需 `pip install matplotlib`。都從 repo 根目錄執行。

| 檔案 | 用途 | 誰用 |
|---|---|---|
| `analyze_trials.py` | 統計錄到的動作資料：每種動作的數據、偵測率、誤報率、閾值掃描與建議值、波形圖 | 所有人。用法見 `docs/manual/03-fall-experiment-guide.md` |
| `make_demo_trials.py` | 產生**假的**動作資料到 `data/demo_trials/`，沒有板子時練習用 | 所有人 |
| `fall_model.py` | 跌倒判定的電腦版，和 `rtl/fall/` 的 Verilog 逐位元相同 | 被上面兩支程式使用；整合者維護 |
| `gen_fall_vectors.py` | 由電腦版模型產生 `sim/fall/fall_vectors.mem`，給 testbench 比對硬體 | 整合者，改了判定邏輯之後執行 |

假資料不能用在報告或用來決定閾值。
