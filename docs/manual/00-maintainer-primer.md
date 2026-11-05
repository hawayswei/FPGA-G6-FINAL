# 整合者入門：git 概念與監督清單

給整合者（本人）看。目標：看得懂 Claude Code 在做什麼、判斷它做得對不對、知道哪些事只能你自己做。

## 一、十個概念（先直覺，再精確）

| 詞 | 直覺 | 精確說明 |
|---|---|---|
| repository（repo） | 一個有「歷史紀錄」的專案資料夾 | 資料夾內多了隱藏的 `.git`，儲存所有版本 |
| commit | 存檔點，附一句說明 | 一組變更的快照，有唯一編號，之後可回到任一 commit |
| branch（分支） | 平行的工作線 | 指向某個 commit 的名字；在分支上 commit 不影響其他分支 |
| clone | 第一次把雲端 repo 整份複製到自己電腦 | 下載全部歷史並設定好遠端 `origin` |
| push | 把我的 commit 傳到 GitHub | 更新遠端的同名分支 |
| fetch / pull | 看看／拉下雲端的新東西 | fetch 只下載不改我的檔案；pull ＝ fetch ＋ merge |
| merge | 把兩條分支的變更合在一起 | 三方合併：比對兩邊與共同祖先，只有雙方都改同一處才衝突 |
| Pull Request（PR） | 在 GitHub 上「請求合併」的公告單 | 本專案只當公告與存檔，不設審核關卡 |
| conflict | git 不知道該聽誰的 | 同一處被雙方改成不同內容；需人決定 |
| tag | 貼在某個 commit 上的書籤 | 本專案用來標記 `proposal-v1`、`video-v1` 等里程碑 |

另外：`.gitignore` ＝「不要追蹤這些檔案」的清單；`origin` ＝ GitHub 上那份的代名詞。

## 二、只有你能親手做的事

1. 安裝 Git 與 GitHub CLI（若 Claude Code 提議 `winget install`，核准即可）。
2. 執行 `gh auth login`：選 GitHub.com、HTTPS、用瀏覽器登入。**不要把 token 貼給任何 AI。**
3. 確認 repo 是 **Private** 之後才讓它推送。
4. 提供兩位組員的 GitHub 帳號名稱，並在邀請前確認拼字。
5. 在 Vivado 裡接上板子、燒錄、回報 LED 實際行為（AI 看不到實體板子）。

## 三、監督 Claude Code 時的檢查點

建議每一步都看它的指令，不確定就問「這行在做什麼」。

**可以放心核准的指令**：`git status`、`git log`、`git diff`、`git add`、`git commit`、`git branch`、`git fetch`、`gh repo create ... --private`、`git push -u origin <分支>`。

**看到就要停下來問清楚**：

- `--force`、`-f`、`push -f`：覆蓋遠端歷史。
- `git reset --hard`、`git clean -fd`、`git checkout -- .`：丟掉本地修改。
- `rm -rf`、`Remove-Item -Recurse`：刪資料夾。
- `git add -f`：繞過 `.gitignore`。
- 推到 `main` 以外、而且分支名稱你不認得的地方。
- 任何要你貼 token、密碼、金鑰的要求。

**每次 commit 前**：看 `git status` 輸出，確認沒有 `vivado_prj/`、`build/`、`.bit`、影片、`.log`。

**每次合併組員分支前**：
1. 先 `git fetch`，用 `git log main..member-b --oneline` 看他做了什麼。
2. `git diff main...member-b --stat` 看改了哪些檔案；有沒有動到只有你能改的檔案（`pet_top.v`、`constr/`、`ip/`、`scripts/`）。
3. 在你的電腦跑 `scripts/check.bat`，要看到 PASS。
4. 能的話上板測，再合併。
5. 合併後 `git push`，在需要時打 tag。

## 四、遇到衝突怎麼辦

1. 組員回報衝突時，請他截圖，不要讓他自己處理。
2. 你在自己電腦切到他的分支或做合併，讓 Claude Code 列出衝突檔案與雙方的版本。
3. 先問「兩段修改的意圖是什麼」，由你決定保留誰、或兩者合併，再讓 Claude Code 套用。
4. 解完後跑 `scripts/check.bat`，PASS 才 commit。

## 五、日常指令速查（給你自己看懂，不需要背）

| 想做的事 | 指令 |
|---|---|
| 現在在哪個分支、有什麼未存的變更 | `git status` |
| 最近誰改了什麼 | `git log --oneline -15` |
| 看某分支比 main 多了什麼 | `git log main..member-b --oneline` |
| 打里程碑標籤 | `git tag proposal-v1` 再 `git push origin proposal-v1` |

## 六、第一次完整演練之後

等第一位組員實際走過 README 的流程（clone、建專案、推送自己的分支），再回頭補 `docs/manual/` 的圖文 SOP，因為截圖需要真實畫面。這份入門保留給你自己使用。
