# ml/

CNN 的訓練、量化與匯出（Python），以及給 FPGA 用的**小型**權重檔。

| 放這裡 | 不放這裡 |
|---|---|
| 訓練與量化腳本（`.py`、`requirements.txt`） | 資料集（`ml/data/`，已被忽略；放 Google Drive） |
| 量化後的權重 `.mem` / `.coe` / `.hex` | 大型模型檔 `.pt`、`.pth`、`.h5`、`.ckpt`（已被忽略） |
| 說明文件：模型架構、輸入尺寸、量化位寬、準確率 | 訓練產生的大量圖片與日誌 |

建議在這裡的 `MODEL.md` 記錄：輸入格式、層結構、權重位寬、權重檔與 `rtl/cnn/` 模組的對應關係，這樣硬體端知道怎麼讀。

CNN 的工具鏈（例如是否用 HLS 產生 Verilog）尚未決定；若有自動產生的 Verilog，請放 `rtl/cnn/generated/` 並在檔頭註明產生來源。
