# FPGA-G6-FINAL：第 6 組期末專題

> **給人看的文件在這份 README 和 `docs/manual/`；給 AI agent 看的在 `CLAUDE.md`。**
> 這個 repo 是我們三人共同編輯期末專題內容的地方，用 GitHub 同步。**專題題目還沒決定**，所以目前只有 git 使用方式與課程規定，沒有任何程式碼。

## 目前狀態

- 專題題目：**尚未決定**（討論中）。
- repo 內容：git 設定檔、使用手冊、課程規定。專題定案後，整合者會建立資料夾架構與規則，再更新這份 README。
- 板子與工具：PYNQ-Z2、Vivado 2019.2（全組同一版本）。

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

1. **開工前**：把別人已合併進 `main` 的內容同步到你的分支（GitKraken 見手冊第 7 節 A；GitHub Desktop 選單 *Branch → Update from main*）。
2. **編輯**自己的檔案。
3. **存檔上傳**：填一行英文訊息（格式 `[docs] what changed`），Commit，再 Push 到自己的分支。
4. **跟整合者說一聲**，他會合併進 `main`。

## 資料夾地圖

| 位置 | 放什麼 | 誰可以改 |
|---|---|---|
| `docs/spec/` | 課程的題目、評分、採購、影片與報告規定 | 大家 |
| `docs/manual/` | 操作手冊（GitKraken 版） | 整合者維護 |
| `docs/README.md` | `docs/` 的索引 | 整合者 |
| `.gitignore`、`.gitattributes` | git 設定（擋掉不該上傳的檔案、統一換行字元） | 整合者 |

專題定案後會新增放程式碼、測試、約束檔等的資料夾，到時候這張表會更新。

## 誰負責什麼

| 角色 | 人員 | 負責 |
|---|---|---|
| 整合者 | （待填） | repo 設定、合併 `main`；平常編輯用 `member-a` 分支 |
| 成員 B（分支 `member-b`） | （待填） | （待定） |
| 成員 C（分支 `member-c`） | （待填） | （待定） |

題目與分工決定後更新這張表。

## 不要放進 repo 的東西

影片（放 Google Drive）、`.bit` 燒錄檔、Vivado 專案資料夾（`vivado_prj/` 等）、資料集、大型模型檔、帳號密碼與學號等個人資料。**這個 repo 是 Public，任何人都看得到。** `.gitignore` 已擋掉大部分，但請你自己也留意。

## 重要日期

11/8 分組截止、11/15 專題提案、12/7 介紹影片、12/14 期末專題展、12/21 書面報告。日期若調整，整合者會用 tag 標記各階段版本。

## 遇到問題

先看 `docs/manual/`；還是不行就把畫面截圖傳給整合者。**遇到不確定的 git 動作，先問再做。**
