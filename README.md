# FPGA-G6-FINAL：隱形守護者（暫定名稱）

> **給人看的文件在這份 README 和 `docs/manual/`；給 AI agent 看的在 `CLAUDE.md`。**
> 這個 repo 是我們三人共同編輯期末專題內容的地方，用 GitHub 同步。專題題目為「隱形守護者」（暫定），目前有基本骨架（頂層、重置同步、heartbeat、腳本），各子系統程式碼之後陸續加入。

## 目前狀態

用 PYNQ-Z2 板子做穿戴式長者照護裝置：加速度計（PmodACL2）與溫度計（Pmod TMP3）綁在上臂，FPGA 以硬體邏輯判定跌倒與體溫異常。偵測到跌倒後 OLED 詢問「Are you OK?」，配戴者 10 秒內可按鈕取消，否則進入 ALARM 並用藍牙通知手機；也可按鈕手動求救。手機藍牙可設定使用者模式與身高。全部寫在 PL（可程式邏輯）端，純 Verilog，不用 ARM 處理器，不使用機器學習。

## 你只需要記得三件事

1. **只改自己負責的檔案。** 要改別人的檔案、`.gitignore`、`.gitattributes`，先跟整合者說。
2. **只推自己的分支**（例如 `member-b`），不碰 `main`。合併進 `main` 由整合者做。
3. **看到「conflict／衝突」就停手，截圖給整合者。** 不要自己選、不要按 Force push、不要按 Discard。

## 第一次設定（約 15 分鐘）

使用 GitKraken 的人，請直接照 `docs/manual/01-gitkraken-guide.md` 的第 1～5 節做（註冊、接受邀請、安裝、clone、切換分支）。repo 目前是 Public，GitKraken 免費版可以用；若之後改回 Private，請改用 GitHub Desktop。

使用 GitHub Desktop 的人：

1. 安裝 [GitHub Desktop](https://desktop.github.com/)，用你的 GitHub 帳號登入。
2. 接受整合者寄來的 repo 邀請信（到信箱按 Accept）。
3. 選 *File → Clone repository*，找到 `FPGA-G6-FINAL`，**Local path 選純英文路徑**，建議 `D:\FPGA\FPGA-G6-FINAL`（不要有中文、不要太長）。
4. 在上方 *Current branch* 切換到你的分支，不是 `main`。

## 每天的工作流程

1. **開工前**：GitHub Desktop 選單 *Branch → Update from main*，把別人已合併的東西拉進你的分支。若 Vivado 專案開著，再執行一次上面的 `source ...create_project.tcl`，新檔案才會出現。
2. **在 Vivado 裡寫程式**，用 *Run Synthesis* 確認沒有錯誤。
3. **存檔上傳**：GitHub Desktop 左下角填一行英文訊息（格式 `[acl] add SPI controller`），按 *Commit to 你的分支*，再按上方 *Push origin*。
4. **跟整合者說一聲**，他會合併。合併前請告訴他：這版有沒有上板測過。
5. 想確認整個設計沒壞，可雙擊 `scripts/check.bat`（需要幾分鐘，建議但不強制）。

## 資料夾地圖

| 位置 | 放什麼 | 誰可以改 |
|---|---|---|
| `rtl/top/` | 頂層 `guardian_top.v`，把所有子系統接起來 | 整合者 |
| `rtl/accel/` `fall/` `temp/` `bluetooth/` `oled/` `ctrl/` | 各子系統的 Verilog（資料夾清單暫定） | 該子系統負責人 |
| `sim/` | testbench（結構和 `rtl/` 一樣） | 負責人 |
| `constr/` | 腳位與時序約束 `.xdc`（依功能拆檔） | 整合者 |
| `ip/` | Vivado IP 的 `.xci` | 整合者 |
| `scripts/` | 建專案、檢查、備用 `.bat` 腳本 | 整合者 |
| `docs/` | 題目規定、手冊、模板、AI 規則 | 大家 |

專題定案後會新增放程式碼、測試、約束檔等的資料夾，到時候這張表會更新。

## 誰負責什麼

| 角色 | 人員 | 負責 |
|---|---|---|
| 整合者 | （待填） | `guardian_top`、`constr/`、`ip/`、`scripts/`、合併 `main`；平常寫程式用 `member-a` 分支 |
| 成員 B（分支 `member-b`） | （待填） | （待定） |
| 成員 C（分支 `member-c`） | （待填） | （待定） |

子系統分工在 11/15 提案前後確定，之後更新這張表。

## 命名與寫法規則（精簡版）

- 只用 **Verilog-2001**（`.v`），不用 SystemVerilog。一個檔案一個模組，檔名＝模組名。
- 模組名加子系統前綴：`acl_` `fall_` `tmp_` `bt_` `oled_` `ctrl_`。
- 埠名結尾：輸入 `_i`、輸出 `_o`；低電位有效在前面加 `_n`，如 `rst_n_i`。
- 全專案只用一個時脈（125 MHz 的 `sysclk_i`），慢速用 enable 訊號，**不要自己除頻產生新時脈**。
- 重置統一為同步、低電位有效的 `rst_n`，由 `guardian_top` 統一提供。
- 程式碼、註解、commit 訊息一律英文；分支名稱 `member-b` 這種英文格式。
- 用 AI 聊天產生程式碼時，先把 `docs/AI_RULES.md` 的內容貼給它。

## 不要放進 repo 的東西

影片（放 Google Drive）、`.bit` 燒錄檔、Vivado 專案資料夾（`vivado_prj/` 等）、資料集、大型模型檔、帳號密碼與學號等個人資料。**這個 repo 是 Public，任何人都看得到。** `.gitignore` 已擋掉大部分，但請你自己也留意。

## 重要日期

11/8 分組截止、11/15 專題提案、12/7 介紹影片、12/14 期末專題展、12/21 書面報告。日期若調整，整合者會用 tag 標記各階段版本。

## 遇到問題

先看 `docs/manual/`；還是不行就把畫面截圖傳給整合者。**遇到不確定的 git 動作，先問再做。**
