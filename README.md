# FPGA-G6-FINAL：桌面寵物（暫定名稱）

> **給人看的文件在這份 README 和 `docs/manual/`；給 AI agent 看的在 `CLAUDE.md` 和 `docs/AI_RULES.md`。**
> 這個 repo 是我們三人共同編輯 Verilog 的地方。程式碼同步靠 GitHub，編譯與燒錄仍在各自電腦的 Vivado 2019.2 上做。

## 這個專案是什麼

用 PYNQ-Z2 板子做一隻桌面寵物：鏡頭看手勢、雲台與小手臂動作、HDMI 顯示狀態、藍牙用手機遙控。全部寫在 PL（可程式邏輯）端，純 Verilog，不用 ARM 處理器。

## 你只需要記得三件事

1. **只改自己負責的資料夾**（見下方表格）。要改別人的檔案、`top`、`constr/`、`ip/`、`scripts/`，先跟整合者說。
2. **只推自己的分支**（例如 `member-b`），不碰 `main`。合併進 `main` 由整合者做。
3. **看到「conflict／衝突」就停手，截圖給整合者**。不要自己選、不要按 Force push、不要按 Discard。

## 第一次設定（約 15 分鐘）

1. 安裝 [GitHub Desktop](https://desktop.github.com/)，用你的 GitHub 帳號登入。
2. 接受整合者寄來的 repo 邀請信（到信箱按 Accept）。
3. 在 GitHub Desktop 選 *File → Clone repository*，找到 `FPGA-G6-FINAL`，**Local path 選純英文路徑**，建議 `D:\FPGA\FPGA-G6-FINAL`（不要有中文、不要太長）。
4. 在 GitHub Desktop 上方切換到你的分支（*Current branch*），不是 `main`。
5. 開 Vivado 2019.2，在底部 **Tcl Console** 輸入（斜線用 `/`）：

   ```
   source D:/FPGA/FPGA-G6-FINAL/scripts/create_project.tcl
   ```

   專案會建在 `vivado_prj/` 裡。之後你在 Vivado 改的 `.v` 檔，就是 repo 裡的檔案本身。

> 圖文版逐步 SOP 在 `docs/manual/`（整合者完成第一次完整演練後補上）。

## 每天的工作流程

1. **開工前**：GitHub Desktop 選單 *Branch → Update from main*，把別人已合併的東西拉進你的分支。若 Vivado 專案開著，再執行一次上面的 `source ...create_project.tcl`，新檔案才會出現。
2. **在 Vivado 裡寫程式**，用 *Run Synthesis* 確認沒有錯誤。
3. **存檔上傳**：GitHub Desktop 左下角填一行英文訊息（格式 `[cam] add capture FSM`），按 *Commit to 你的分支*，再按上方 *Push origin*。
4. **跟整合者說一聲**，他會合併。合併前請告訴他：這版有沒有上板測過。
5. 想確認整個設計沒壞，可雙擊 `scripts/check.bat`（需要幾分鐘，建議但不強制）。

## 資料夾地圖

| 資料夾 | 放什麼 | 誰可以改 |
|---|---|---|
| `rtl/top/` | 頂層 `pet_top.v`，把所有子系統接起來 | 整合者 |
| `rtl/camera/` `vision/` `cnn/` `hdmi/` `servo/` `bluetooth/` `ctrl/` | 各子系統的 Verilog | 該子系統負責人 |
| `sim/` | testbench（結構和 `rtl/` 一樣） | 負責人 |
| `constr/` | 腳位與時序約束 `.xdc`（依功能拆檔） | 整合者 |
| `ip/` | Vivado IP 的 `.xci` | 整合者 |
| `ml/` | CNN 訓練程式與小型權重檔 | CNN 負責人 |
| `scripts/` | 建專案、檢查、備用 `.bat` 腳本 | 整合者 |
| `docs/` | 題目規定、手冊、模板、AI 規則 | 大家 |

每個資料夾裡都有 `README.md`，說明該資料夾的用途與規則。

## 誰負責什麼

| 角色 | 人員 | 負責 |
|---|---|---|
| 整合者 | （待填） | `pet_top`、`constr/`、`ip/`、`scripts/`、合併 `main` |
| 成員 B | （待填） | （待定） |
| 成員 C | （待填） | （待定） |

子系統分工在 11/15 提案前後確定，之後更新這張表。

## 命名與寫法規則（精簡版）

- 只用 **Verilog-2001**（`.v`），不用 SystemVerilog。一個檔案一個模組，檔名＝模組名。
- 模組名加子系統前綴：`cam_` `vis_` `cnn_` `hdmi_` `srv_` `bt_` `ctrl_`。
- 埠名結尾：輸入 `_i`、輸出 `_o`；低電位有效在前面加 `_n`，如 `rst_n_i`。
- 全專案只用一個時脈（125 MHz 的 `sysclk_i`），慢速用 enable 訊號，**不要自己除頻產生新時脈**。
- 重置統一為同步、低電位有效的 `rst_n`，由 `pet_top` 統一提供。
- 程式碼、註解、commit 訊息一律英文；分支名稱 `member-b` 這種英文格式。
- 用 AI 聊天產生程式碼時，先把 `docs/AI_RULES.md` 的內容貼給它。

## 不要放進 repo 的東西

影片（放 Google Drive）、`.bit` 燒錄檔（里程碑時由整合者放 GitHub Releases）、`vivado_prj/` 專案資料夾、資料集、大型模型檔。`.gitignore` 已擋掉大部分，但請你自己也留意。

## 重要日期

11/8 分組截止、11/15 專題提案、12/7 介紹影片、12/14 期末專題展、12/21 書面報告。日期若調整，整合者會用 tag（`proposal-v1` 等）標記各階段版本。

## 遇到問題

先看 `docs/manual/`；還是不行就把畫面截圖傳給整合者。**遇到不確定的 git 動作，先問再做。**
