# GitKraken 使用手冊（組員版）

給組員看的圖形介面 git 手冊。照順序做，每一節做完再進下一節。
**畫面按鈕的文字可能因 GitKraken 版本略有不同，找不到就截圖問整合者，不要亂按。**

## 先看這三條鐵則

1. **只改自己負責的檔案**（分工見根目錄 `README.md`；專案內容還沒定案時，先只動 `docs/` 裡自己的文件）。
2. **只推自己的分支**（`member-b`、`member-c` 等），不要碰 `main`。
3. **看到「conflict／衝突」就停手，截圖給整合者**，不要自己選、不要按 Force push。

## 這份手冊和其他文件的關係

| 想知道什麼 | 看哪份文件 | 位置 |
|---|---|---|
| 專案目前的狀態、資料夾、基本規則 | 根目錄 README | `README.md` |
| 用 GitHub Desktop 的操作（備用） | 根目錄 README | `README.md`（第一次設定、每天的工作流程） |
| 用 GitKraken 的操作（這份） | 本手冊 | `docs/manual/01-gitkraken-guide.md` |
| git 名詞的直覺解釋 | 本手冊第 9 節 | `docs/manual/01-gitkraken-guide.md` |
| 課程題目、評分、日期 | 課程規定 | `docs/spec/` |

## 快速索引：我遇到的問題在哪一節？

| 我想問的問題 | 看哪一節 |
|---|---|
| 我還沒有 GitHub 帳號 | 第 1 節 |
| 整合者說已經邀請我，我要怎麼確認 | 第 2 節 |
| 我下載了 GitKraken 並登入了，**要怎麼打開這個 repo** | 第 4 節 A |
| 我要**選擇 repo 放在電腦哪裡** | 第 4 節 B |
| 我已經下載過了，**下次要怎麼再打開** | 第 4 節 C |
| 我打開 repo 了，**怎麼切換到我的分支** | 第 5 節 |
| 我要用 Vivado 開專案 | 第 6 節（目前還沒有，定案後補上） |
| 我要同步、存檔、上傳 | 第 7 節 |
| 畫面出現奇怪的東西或錯誤 | 第 8 節 |

## 目錄

1. 註冊 GitHub 帳號
2. 接受 repo 邀請
3. 下載並安裝 GitKraken，登入
4. 把 repo 下載到你的電腦（Clone）
5. 切換到你自己的分支（Checkout）
6. 用 Vivado 開啟專案（待專案定案後補上）
7. 每天的工作流程：同步、存檔、上傳
8. 出問題怎麼辦
9. 名詞對照
10. 附錄：整合者專用（合併分支）

---

## 1. 註冊 GitHub 帳號

已經有帳號的人跳到第 2 節。

1. 打開 [github.com/signup](https://github.com/signup)。
2. 輸入 Email、密碼、使用者名稱（username）。
   - Email 用你收得到信的信箱，邀請信會寄到這裡。
   - username 用英文，不要放真實姓名或學號。
3. 完成人機驗證，再輸入信箱收到的驗證碼。
4. 註冊完成後，**把你的 username 傳給整合者**，他才能邀請你。

> 註冊用的密碼自己保管，不要傳給任何人，也不要貼給 AI。

## 2. 接受 repo 邀請

repo 雖然是公開的（任何人都能看和下載），但**只有被邀請的人才能推送修改**。所以一定要接受邀請。

1. 整合者邀請你後，你的信箱會收到 GitHub 的邀請信。
2. 打開信，按 **View invitation**（或 **Accept invitation**）。
3. 網頁會問你是否加入，按 **Accept invitation**。
4. 邀請有時效，**收到後請盡快接受**。找不到信也可以直接開
   `https://github.com/hawayswei/FPGA-G6-FINAL/invitations` 接受。

接受之後，在 repo 首頁 `github.com/hawayswei/FPGA-G6-FINAL` 應該看得到 Settings 以外的所有內容。

## 3. 下載並安裝 GitKraken，登入

1. 打開 [gitkraken.com/download](https://www.gitkraken.com/download)，下載 Windows 版。
2. 執行安裝檔，一直按下一步安裝。
3. 第一次開啟會出現 **Welcome to GitKraken** 視窗，按 **Sign in with GitHub**。
4. 瀏覽器會跳出授權頁，登入 GitHub 並按授權（Authorize），再回到 GitKraken。

**提交者名稱與 Email：** 如果 GitKraken 在你第一次存檔（commit）時要求填名稱與 Email：
- 名稱填你的名字或 username。
- Email 建議用 GitHub 的「noreply」信箱，避免真實信箱公開。到 GitHub 網頁 *Settings → Emails*，勾選 *Keep my email addresses private*，頁面上會顯示一個像 `數字+username@users.noreply.github.com` 的地址，複製來用。

> 免費版 GitKraken 只能連**公開**的 repo。如果整合者哪天把 repo 改回 Private，GitKraken 會連不上，請改用 GitHub Desktop（見根目錄 `README.md`）。

## 4. 把 repo 下載到你的電腦（Clone）

**名詞：** *Clone* 就是「第一次把 GitHub 上的專案整份下載到你的電腦」。你的電腦現在還沒有這個專案，所以第一次要用 **Clone**，**不是 Open**。

### A. 第一次打開這個 repo（Clone）

前提：你已經完成第 3 節（GitKraken 安裝並登入）。

1. 在 GitKraken 上方選單按 **File → Clone Repo**。有些版本叫 *Clone / Init / Open*，或在畫面中央的 *Repository Management* 分頁按 **Clone**。
2. 跳出視窗後，有兩種方式找到 repo，**選一種**：
   - **方法 1（用網址，最不容易出錯）**：選 **URL**，在輸入欄貼上
     `https://github.com/hawayswei/FPGA-G6-FINAL.git`
   - **方法 2（用帳號清單）**：選 **GitHub.com**，在清單裡找 `hawayswei/FPGA-G6-FINAL`。如果清單裡找不到，直接改用方法 1。
3. 選下載位置（見下面 B）。
4. 按 **Clone the repo!**，等進度跑完。
5. 完成後按 **Open Now**。

**怎麼知道成功了：** GitKraken 中間出現一張有很多圓點和線的圖（叫 Commit Graph），左邊面板出現 **LOCAL**、**REMOTE** 等分類，上方分頁顯示 `FPGA-G6-FINAL`。

### B. 選擇 repo 放在電腦哪裡

在 Clone 視窗裡，會有一格選擇「要下載到哪個資料夾」（欄位名稱通常是 **Where to clone to**，旁邊有 **Browse**／瀏覽按鈕；名稱可能因版本略有不同）。

1. 按 **Browse**，會開啟 Windows 的選資料夾視窗。
2. 選 `D:\FPGA`。如果還沒有這個資料夾，在選資料夾視窗點 **新增資料夾**，建立一個叫 `FPGA` 的資料夾，再選它。
3. 如果你的電腦**沒有 D 槽**，改選 `C:\FPGA`（一樣先建立 `FPGA` 資料夾）。
4. 看視窗下方的完整路徑（通常標示 *Full path*），**必須剛好是 `D:\FPGA\FPGA-G6-FINAL`**（或 `C:\FPGA\FPGA-G6-FINAL`）。
   - 常見錯誤：變成 `D:\FPGA\FPGA-G6-FINAL\FPGA-G6-FINAL`（多了一層）。如果這樣，把選擇的位置改回上一層的 `D:\FPGA`。

**路徑規則（很重要，Vivado 2019.2 遇到中文路徑常會出錯）：**

| 可以 | 不可以 |
|---|---|
| `D:\FPGA\FPGA-G6-FINAL` | 路徑裡有中文，例如 `D:\學校\專題\...` |
| `C:\FPGA\FPGA-G6-FINAL` | 放在 `C:\Users\你的名字\...` 底下，**尤其是 Windows 使用者名稱是中文時** |
| 路徑短、只有英文字母和數字 | 放在桌面、文件、OneDrive（容易有中文路徑，也容易被雲端同步干擾） |

**如果已經放錯位置了：** 在 GitKraken 關閉這個 repo 分頁，用檔案總管把整個 `FPGA-G6-FINAL` 資料夾刪掉，再從 A 重新做一次。（還沒有修改任何東西之前重新 Clone 最安全。）

### C. 以後怎麼再次打開（不需要再 Clone）

已經下載過之後，下次打開 GitKraken：

- 通常會自動打開上次的 repo 分頁。
- 沒有的話，按左上角的**資料夾圖示**（或快捷鍵 `Ctrl + O`），選 **Browse**，選 `D:\FPGA\FPGA-G6-FINAL`。
- 也可以在 *Repository Management* 分頁的最近使用清單裡點它。

**不要再按一次 Clone**，否則會下載出第二份，之後很容易搞混哪份才是你在用的。

## 5. 切換到你自己的分支（Checkout）

**名詞：** 分支（branch）就是你自己的獨立工作線。你在自己的分支上做事，不會影響別人，也不會影響 `main`。切換分支叫 **Checkout**。

**先確認你的分支名稱**（整合者會告訴你）：

| 人 | 分支 |
|---|---|
| 整合者 | `member-a`（合併時才用 `main`） |
| 組員 B | `member-b` |
| 組員 C | `member-c` |

剛 Clone 完時，你停在 `main`。**不要在 `main` 上做任何修改。**

**步驟：**

1. 看畫面**左邊面板**。往下找到 **REMOTE**，點它旁邊的箭頭展開，再展開 **origin**，會看到 `main`、`member-a`、`member-b`、`member-c`。
2. **用滑鼠雙擊你自己的分支名稱**，例如 `member-b`。
   - 如果跳出詢問，選擇「建立本機分支並切換」或 **Checkout**。
   - 也可以改用右鍵點分支名稱，選 **Checkout**。
3. 切換完成。

**怎麼確認真的切過去了（三個檢查點）：**

1. 左邊面板 **LOCAL** 底下出現你的分支名稱，而且**名稱是粗體**或旁邊有打勾標記，那就是目前所在的分支。
2. 中間 Commit Graph 上，你的分支名稱旁邊有一個圓形標記。
3. 用檔案總管看 `D:\FPGA\FPGA-G6-FINAL`，資料夾內的檔案會是你分支的內容（剛建立的分支內容和 `main` 一樣）。

**如果在 REMOTE 底下看不到你的分支：** 按上方 **Pull** 旁邊的小箭頭，選 **Fetch All**，再看一次。還是沒有就截圖給整合者（可能還沒推到 GitHub）。

**每次開工前都要看一眼：** 確認你在自己的分支上。如果發現在 `main` 上，**不要存檔，先切回自己的分支**。

## 6. 用 Vivado 開啟專案（待補）

我們還沒決定要做什麼專題，所以 repo 裡目前**沒有**任何程式碼或 Vivado 專案。這一節等專題定案、整合者放好專案架構後再補上。現在先熟悉第 1～5 節與第 7 節的流程就好。

## 7. 每天的工作流程

整個流程是：**A 同步 → B 寫程式 → C 存檔 → D 上傳 → E 通知。**

### A. 開工前：把最新的 main 同步到你的分支

目的：拿到整合者合併進 `main` 的新東西，讓你的版本不要落後太多。

1. 確認你在自己的分支（第 5 節）。
2. 上方工具列找到 **Pull**，按旁邊的小箭頭展開，選 **Fetch All**。這一步只是「看看有什麼新東西」，不會改你的檔案。
3. 左邊面板 **REMOTE → origin**，找到 `main`，**按右鍵**，選 **Merge**（文字類似「Merge origin/main into 你的分支」）。
4. 結果有兩種：
   - 順利：圖上會出現新的合併節點，或顯示已經是最新。做完就繼續。
   - 出現 **conflict／衝突** 字樣：**停手，截圖給整合者。**
5. 合併成功後，看一下資料夾裡有沒有新增或更新的檔案。

> 你自己的分支只有你在推，所以不需要對自己的分支按 Pull。

### B. 編輯內容

目前 repo 裡只有文件，可以在 `docs/` 底下新增或修改自己的文件（Markdown 或文字檔都可以）。專案定案、有程式碼之後，這裡會補上程式的規則。

### C. 存檔（Commit）

存檔就是「替目前的修改做一個可以回頭的存檔點」。

1. 在你的編輯器儲存所有檔案（Ctrl+S）。
2. 回到 GitKraken，圖最上方會多出一個 **WIP**（Work In Progress）節點，**點它**。
3. 右邊面板會列出所有改過的檔案。**逐一看一下**，確認：
   - 都是你自己改的檔案。
   - 沒有 `vivado_prj`、`build`、`.bit`、`.log`、影片之類的東西。
4. 按 **Stage all changes**（全部加入），或點個別檔案的勾選框。
5. 在訊息欄輸入一行**英文**說明，格式 `[區域] 做了什麼`，例如：
   - `[docs] add meeting notes 11/10`
   - `[docs] fix typo in README`
   區域代號先用 `docs`；專題定案後整合者會公告更細的分類。
6. 按 **Commit**（綠色按鈕）。

### D. 上傳（Push）

1. 確認你在自己的分支。
2. 按上方工具列的 **Push**。
3. 如果是這條分支第一次推，GitKraken 會問要不要在遠端建立同名分支，確認即可。
4. 完成後，打開 `github.com/hawayswei/FPGA-G6-FINAL`，切到你的分支，應該看得到你剛才的 commit。

### E. 通知整合者

在群組說一聲：「`member-b` 推了新版本，內容是 ○○，**有／沒有**上板測過。」整合者會負責合併進 `main`。

## 8. 出問題怎麼辦

| 狀況 | 怎麼做 |
|---|---|
| 出現 conflict／衝突 | 停手，截圖給整合者 |
| Push 失敗，顯示沒有權限（403 或 permission） | 你可能還沒接受邀請（第 2 節），或登入的帳號不對 |
| 左邊面板看不到別人的分支 | 按 Pull 旁邊的小箭頭 → **Fetch All** |
| 發現自己在 `main` 上而且已經改了檔案 | **不要 commit、不要 push**，截圖給整合者 |
| 不小心 commit 了不該放的檔案（如 `.bit`、`vivado_prj`） | 還沒 push：截圖給整合者。已經 push：立刻告訴整合者，不要自己處理 |
| 路徑含中文（之後用 Vivado 會出錯） | 關閉 GitKraken 的該 repo，刪掉資料夾，重新 Clone 到 `D:\FPGA\FPGA-G6-FINAL`（第 4 節 B） |
| 我不小心 Clone 了兩次 | 只留一份，其他的先問整合者再刪；之後用第 4 節 C 打開，不要再 Clone |
| 找不到 Clone 的選項 | 看 File 選單，或 *Repository Management* 分頁；名稱可能叫 *Clone / Init / Open* |
| 不確定能不能按某個按鈕 | **先問再按** |

**這些按鈕不要按（除非整合者叫你按）：** Force push、Reset、Delete branch、Discard all changes、Rebase。

## 9. 名詞對照

| 英文 | 白話 |
|---|---|
| repository（repo） | 專案資料夾，帶有完整歷史紀錄 |
| clone | 第一次把 GitHub 上的專案整份下載到自己電腦 |
| branch | 分支，你自己的獨立工作線 |
| checkout | 切換到某條分支 |
| fetch | 看看遠端有什麼新東西，不改你的檔案 |
| merge | 把兩條分支的修改合在一起 |
| stage | 挑出這次要存檔的檔案 |
| commit | 存檔點，附一行說明 |
| push | 把你的存檔點上傳到 GitHub |
| conflict | 兩個人改了同一個地方，git 不知道該聽誰的 |
| WIP | 還沒存檔的修改 |
| origin | GitHub 上那份的代名詞 |

---

## 10. 附錄：整合者專用（合併組員分支）

只有整合者做這一節。

1. 先在自己的分支（`member-a`）把手上的修改 commit 好。
2. 左邊面板 **LOCAL** 雙擊 `main`，切換到 `main`。
3. 按 Pull 旁邊小箭頭 → **Fetch All**，再確認 `main` 是最新。
4. 在左邊面板 **REMOTE → origin** 找到要合併的分支（例如 `member-b`），**按右鍵選 Merge**，把它合進目前的 `main`。
5. 有衝突時，在右邊面板點有衝突的檔案，會開啟合併工具，逐段決定保留哪一邊。解完再繼續。
6. 按 **Push**，把更新後的 `main` 上傳。
7. 回到 `member-a`，用第 7 節 A 的方式把最新 `main` 合進來。

合併前的檢查：看這個分支改了哪些檔案、有沒有動到不該動的東西（`.gitignore`、`.gitattributes`、別人的文件）；組員有沒有確認內容可以合併。專案有程式碼之後，這裡會加入「合成檢查」與「上板測試」。
