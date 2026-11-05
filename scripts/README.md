# scripts/

**只有整合者編輯這個資料夾。**

| 檔案 | 用途 | 誰用 |
|---|---|---|
| `create_project.tcl` | 在本機建立或更新 Vivado 專案（`vivado_prj/`） | 所有人，每次 pull 後執行 |
| `check.tcl` / `check.bat` | 對整個設計跑一次合成，輸出 PASS / FAIL | 所有人（建議），整合者合併前必跑 |
| `sync.bat` | 備用：把最新 `main` 合進自己的分支 | 沒有裝 GitHub Desktop 時 |
| `save.bat` | 備用：存檔並上傳到自己的分支 | 沒有裝 GitHub Desktop 時 |
| `common.tcl` | 上面 Tcl 腳本共用的小工具與專案常數 | 不要直接執行 |

## 使用方式

- `create_project.tcl`：在 Vivado 底部 Tcl Console 輸入
  `source D:/FPGA/FPGA-G6-FINAL/scripts/create_project.tcl`（路徑改成你自己的位置，斜線用 `/`）。
  可以重複執行；第二次起只會加入新檔案、移除已刪除的檔案。
- `check.bat`：雙擊執行，約需數分鐘。若 Vivado 不在 `D:\Xilinx\Vivado\2019.2` 或 `C:\Xilinx\Vivado\2019.2`，
  先設定環境變數 `VIVADO_BAT` 為 `vivado.bat` 的完整路徑。
- `sync.bat` 與 `save.bat`：**需要另外安裝 Git for Windows**（GitHub Desktop 內建的 git 不在系統路徑裡）。
  沒有安裝的話，請直接用 GitHub Desktop 操作，流程見根目錄 README。

## 注意

- 腳本訊息刻意使用英文，避免 Windows 命令列的中文編碼問題。
- `build/` 與 `vivado_prj/` 是腳本產生的暫存位置，已被 `.gitignore` 擋掉。
