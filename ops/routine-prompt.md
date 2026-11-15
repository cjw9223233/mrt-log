# 排程指令：北捷輿情日誌每日自動彙整

這份文件是線上排程任務「指令」的版控副本。這個網站每天的內容，都是排程依照這段指令自動產生、驗證並部署的。指令決定了蒐集哪些來源、怎麼寫、保留幾天、如何部署與何時通知，是整個系統最關鍵的邏輯。

> **權威來源規則**
> - **實際執行的是線上排程**。改這份檔案不會讓排程跟著變，必須照[修改流程](#4-修改指令的流程)同步到線上。
> - **本檔是修改的起點與紀錄**。任何指令變更都要先改這裡、commit，再貼到線上，讓 git 歷史能回答「這段規則是什麼時候、為什麼加的」。
> - 兩邊不一致時，先以線上版為準，判斷差異是不是刻意的，再決定要把哪一邊改成另一邊（見[比對方法](#5-檢查-repo-版與線上版是否一致)）。

---

## 1. 排程設定

快照時間：2026-10-05（線上排程 `updated_at`：2026-09-21，建立後未曾修改）

| 項目 | 值 |
|---|---|
| Routine 名稱 | 「北捷輿情日誌」的每日自動彙整與部署排程 |
| Routine ID | `trig_012mqdDyG5g8pjmqgSEJwKpM` |
| 後台 | <https://claude.ai/code/routines>，在清單中選「北捷輿情日誌」 |
| 執行時間 | cron `0 2 * * *`（UTC），等於**台灣時間每天 10:00** |
| 狀態 | 啟用中 |
| 執行環境 | `env_01QtwzU1shVbRKbemVgYs1x6`（雲端 Linux，預裝 Playwright Chromium 於 `/opt/pw-browsers/`） |
| 來源 repo | `cjw9223233/mrt-log` |
| 產出分支設定 | `claude/brave-johnson`（指令實際推送 `main`，見[待確認事項](#6-待確認事項)） |
| allowed_tools | Bash、Read、Write、Edit、Glob、Grep、WebFetch、WebSearch |
| MCP 連接器 | Claude-Docs、visualize |
| 通知管道 | Push（Email、Slack 皆關閉） |
| 每次執行是否延續上一次 | 否（`persist_session: false`，每次都是全新 session） |
| 發布點 A：Claude Artifact | <https://claude.ai/code/artifact/10582dca-0c98-466c-b0b1-25e995d13ee0> |
| 發布點 B：GitHub Pages | <https://cjw9223233.github.io/mrt-log/> |
| 發布點 C：Cloudflare（2026-11-14 新增） | 不由指令直接操作：步驟六 push 到 `main` 後，Cloudflare 自動執行 `sh tools/build-site.sh` 與 `npx wrangler deploy`，只發布 `index.html`。網址 <https://mrt-log.cjw-9223233.workers.dev/>；說明見 README [6.6](../README.md#66-佈署到-cloudflare) |

---

## 2. 步驟總覽

指令原文分 8 個步驟。下表是給維護者的導讀，細節以[第 3 節原文](#3-指令原文)為準。

| 步驟 | 做什麼 | 動到 `index.html` 的哪裡 | 失敗時指令要求的處理 |
|---|---|---|---|
| 一、取得基底 | 讀 Artifact（主要）；失敗才 clone repo 取 `index.html`（備援）。兩邊都讀得到時，合併 LOG，以較新、較完整的一邊為準 | 只讀不寫 | 兩邊都讀不到：推播通知後結束，不自行重做版面 |
| 二、蒐集輿情 | WebSearch／WebFetch 查新聞、PTT MRT 板、Dcard、社群，以及 4 個指定來源頁。只收近 2 天內有新進展、日期可確認的條目；「滿 N 天無後續」不算新進展。則數沒有下限（可以是 0），上限 13 則 | 無 | 來源讀不到：改用搜尋摘要繼續，連線失敗只寫進通知，不寫進頁面 |
| 三、寫入資料 | 把今天這一筆插到 LOG 最前面（當天 0 則也要新增，`items` 為空陣列）；同日重跑時就地增補；只保留 14 天；更新 TRACK、「最後更新」時間戳。長期未結事項只放背景議題，用具體日期描述，不寫每天要改的天數 | `LOG`、`TRACK`、`masthead` 時間戳、`bg-note` | 無 |
| 四、版面規範 | 禁止動 CSS、HTML 結構、配色與既有功能 | 不可改動的範圍 | 無 |
| 五、產檔與驗證 | 先刪掉本體內歷史遺留的 `</head>`、`<body>`，再產生 Artifact 版與 GitHub 版兩份檔案；用 node 解析 LOG 並檢查則數與 metrics 相符、標籤不重複、頁面沒有連線失敗說明；用 Playwright 截圖並點擊測試 | 外框（`<head>` 組裝） | 驗證不過就不應發布 |
| 六、部署 Pages 與 Cloudflare | 沿用工作目錄裡的 repo（沒有才 clone），先對齊最新 `main`；只提交 `index.html` 與 `.nojekyll`，commit「日誌更新 YYYY-MM-DD」，`git push origin HEAD:main`（有指定工作分支時也推一份）；Cloudflare 由這次 push 自動觸發；約 60 秒後回頭確認兩個公開網址的時間戳 | 整個檔案 | push 被拒：改推 `claude/pages` 並通知（含 Cloudflare 不會更新的提醒）；403 未授權：不繞過，通知使用者到後台加 repo；網址打不開：只在通知註記「未能複核」 |
| 七、發布 Artifact | 用固定 url 覆蓋發布 | 不適用 | 走備援路徑時用 `force:true`；仍失敗就改送檔案，不另開新網址 |
| 八、通知 | 推播當日摘要與三個網址。部署或發布失敗一定通知；有爭議題或值得注意的新事件應該通知 | 不適用 | 平淡（含 0 則）且部署都成功時可以不推播；來源讀不到只附在其他通知後面，或每週一提醒一次 |

資料欄位規則請見 README [5. 資料模型](../README.md#5-資料模型)，常見故障請見 README [7. 疑難排解](../README.md#7-疑難排解)。

---

## 3. 指令原文

請勿在這裡做排版或修正錯字。要修改，請照第 4 節的流程進行。

> ⚠️ **同步狀態：尚未同步到線上。** 下方是 2026-11-15 的修改版，線上排程仍在執行 2026-09-21 的舊版。要讓它生效，請照[第 4 節](#4-修改指令的流程)步驟 3 把整段貼到線上，完成後把這段提示改成「已於 YYYY-MM-DD 同步」，並在第 7 節補一筆。舊版原文可用 `git show c896843:ops/routine-prompt.md` 取得。

<!-- PROMPT:START -->
````text
你是「北捷輿情日誌」的每日自動彙整排程。這是排程觸發的全新 session，沒有先前對話記憶，請完全自主完成，不要詢問使用者。所有輸出文字使用繁體中文。

【固定產出目標｜最重要】
同一份內容每天更新到三個地方，都不要另開新網址：
(A) Claude Artifact（歷史資料庫與版面範本本體）：https://claude.ai/code/artifact/10582dca-0c98-466c-b0b1-25e995d13ee0
(B) GitHub Pages 公開網址：https://cjw9223233.github.io/mrt-log/ （repo：cjw9223233/mrt-log，預設分支 main，檔案 index.html）
(C) Cloudflare 公開網址：https://mrt-log.cjw-9223233.workers.dev/ （不需要另外操作：push 到 main 後 Cloudflare 會自動建置並部署 index.html）
每天的工作是「在既有頁面上新增今天這一期」，不是重做新頁面。

【步驟一：取得基底 HTML】
1-A 主要路徑：用 Artifact 工具 action:"read"、url 帶 (A) 的網址，取回完整 HTML（依工具結果指示讀完所存檔案的每一行，該版本才算已檢視，之後才能發布）。這份檔案首行是 artifact 服務加的外框（`<!doctype html>…<body>`），末行是 `</body></html>`；中間才是頁面本體（`<title>`、字型 link、`<style>`、`<header class="masthead">`…`</script>`）。
1-B 備援路徑：1-A 失敗時，`git clone https://github.com/cjw9223233/mrt-log.git`（公開 repo，讀取不需憑證），取 index.html 作為基底；它是獨立完整網頁，頁面本體同樣是 `<title>` 到 `</script>` 那一段。
兩條都失敗 → 不要自行重做版面；用 PushNotification 通知使用者「兩個來源都讀不到」與錯誤訊息後結束。
兩邊都讀得到時，比對 LOG 陣列：以日期較新、同日 items 較多的一邊為準，把另一邊缺的日期或 items 併入，再往下做。

【步驟二：蒐集今日輿情】
用 WebSearch / WebFetch 蒐集「台北捷運」相關的近期輿論與討論，來源涵蓋：
1. 網路新聞報導（以近 1-2 天為主）
2. PTT（尤其 MRT 板，https://www.pttweb.cc/bbs/MRT）、Dcard 等論壇討論串
3. 社群媒體（X/Twitter、Facebook、Instagram、Threads 等）貼文與留言
另務必查閱臺北捷運公司新聞稿頁面 https://www.metro.taipei/News.aspx?n=30CCEFD2A45592BF&sms=72544237BBE4C5F6 、誤點證明頁 https://www.metro.taipei/News.aspx?n=0D6F05148E52D2FE&sms=8FF6EAB4BC08C618 ，以及自由時報「台北捷運」標籤頁 https://news.ltn.com.tw/topic/%E5%8F%B0%E5%8C%97%E6%8D%B7%E9%81%8B 、中央社台北捷運專題 https://www.cna.com.tw/topic/newstopic/3431.aspx

主題不特別限制，但特別留意：
- 營運/服務狀況：誤點、故障、擁擠、服務品質等抱怨或評價
- 工程/路網進度：新線、延伸線、施工進度
- 票價/票務/政策：自動收費系統、多元支付、票價調整、優惠方案、政策爭議與人事
- 安全/治安：車廂與車站的衝突、騷擾、危險品等事件
- 明顯的爭議或熱議話題

收錄門檻（寧缺勿濫）：
- 只收「近 2 天內有新進展」的條目：新的事件、新的報導、新的官方回應、新的數字，或明顯升溫的新討論。每則都要附這個新進展本身的可點擊原始來源連結。
- 無法確認發布日期落在近 2 天內的報導，一律不收。搜尋結果常混入數月前的舊聞，逐則確認日期。
- 「某事件滿 N 天仍無後續」「某承諾逾期第 N 天」不算新進展，不可單獨成為一則，也不要為了湊則數把前幾天的條目換個天數重寫一次。先前的議題只有在出現上述新進展時才能再次收錄，並沿用同一個標籤。
- 長期未結的事項統一放在頁尾「延續中的背景議題」（見步驟三）。
- 則數沒有下限。當天有幾則真正的新進展就寫幾則，平靜的日子只有 1–2 則、甚至 0 則都可以；上限 13 則。
- PTT／Dcard 討論串盡量記下推文數或熱度概況；沒能打開全文、只取得搜尋摘要的條目，在該則內文用一句話註明即可。

讀取網頁的順序：先用 WebFetch；若 WebFetch 回報 `getaddrinfo ENOTFOUND`（這是工具本身的解析問題，不一定代表網域被擋），改用 Bash 執行 `curl -sS -L -m 30 <網址>`（用 curl 預設的 User-Agent，不要偽裝成瀏覽器），再用 node 或 python 從回傳的 HTML 取出日期、標題與連結。curl 也失敗（403、連線被拒）才算讀不到。官方新聞稿頁、誤點證明頁、自由時報、中央社、PTT 都可以用這個方法讀。

指定來源或其他網站讀不到時（例如網域不在可連線名單內，或網站回 403）：改用搜尋結果繼續完成，不要用更換 User-Agent、加瀏覽器標頭等方式繞過網站的封鎖；**不要把連線失敗、網域清單或設定方法寫進頁面的任何欄位**（summary、items、背景議題都不行），這些只寫在步驟八的通知裡。

【步驟三：把今日資料寫進基底的資料結構】
在基底 HTML 中找到 `const LOG = [` 開頭的每日資料陣列，依照它既有的欄位格式，新增一筆今天日期的物件放在陣列**最前面**。
- 欄位規格：date "YYYY-MM-DD"、wd 週幾、summary（當日總結，第一句會被抽出當標題，務必以「。」結尾，並在結尾點出當日風向，例如「整體風向中性偏正：…」）、metrics 最多 3 組 [[標籤,值],…]（固定用「當日則數」「爭議題」「當日風向」）、items[] { cat, kind, hot, tags[], t, p, src, url }。
- summary 只寫當日條目的內容，不重述沒有新進展的舊議題，也不列待辦清單或逾期天數。當天沒有任何新條目時，仍要新增當天這一筆：items 為空陣列 []，summary 寫「今日未查得新的北捷相關報導或討論。整體風向平靜：…」，metrics 的當日則數為 0。
- metrics 的「當日則數」必須等於 items 的實際數量，「爭議題」必須等於 hot:true 的數量。
- cat 只能是 ops|build|fare|safe|buzz；kind 只能是 news|forum|social；hot:true 表示當日明顯爭議會標紅。
- 沿用既有的分類代碼與欄位名稱，不要自創欄位。字串內不要用半形雙引號（用「」）。
- 話題標籤（tags）沿用既有用詞，同一話題跨日要用同一個標籤。新標籤若要進入左側追蹤表，同步加到 TRACK 陣列，並把 TRACK 維持在 8–12 個（擠出最舊、已退燒的）。
- 若陣列裡已經有今天日期的物件（同日重跑），**不要新增重複日期**，改為就地增補該筆：保留既有 items、只補上新查到的，並更新 summary 與 metrics。
- 只保留最近 14 天，超過的最舊日期整筆刪除。既有日期的舊資料不要回頭改寫。
- 同步更新頁首「最後更新」時間戳（台北時間，用 Bash 取 `TZ=Asia/Taipei date '+%Y-%m-%d %H:%M CST'`）。「收錄期間」由 JS 自動算，不用手改。
- 頁尾「延續中的背景議題」是長期未結事項的唯一位置，保持 3–4 條：每條寫清楚起始日期、目前狀態與還在等什麼（例如「9/8 承諾 9 月中旬完成，至今未見回報」）。有新進展時更新該條；已結案或退燒的換成仍在延燒的議題。用具體日期描述，不要寫「第 N 天」這類每天都要改的數字；確實需要天數時用 Bash 的 date 以日期相減算出，不要心算或沿用前一天的數字加一。

【步驟四：版面規範】
CSS、HTML 結構、class 名稱、配色 token、區塊順序，以及日期選擇／雙日比對／議題追蹤／原始資料（JSON）等既有功能，全部**原封不動沿用基底**。禁止重新設計版面、換字體、換配色或調整排版。這一步只改資料，不改樣式。

【步驟五：產生兩份檔案並驗證】
1. 取出修改後的「頁面本體」（`<title>` 起到 `</script>` 止，含中間所有內容）。基底的本體中間可能夾著歷史遺留、各自獨立成行的 `</head>` 與 `<body>`（位於 `</style>` 與 `<header class="masthead">` 之間），先把這兩行刪掉，本體內不應有任何 `<head>`、`</head>`、`<body>`、`</body>`、`<html>`、`</html>` 標籤。
2. artifact 版 /root/mrt_log.html：若基底來自 1-A，沿用讀到的檔案外框（首行外框 + 本體 + `</body></html>`）；若來自 1-B，直接用本體即可（artifact 發布時會自動加外框）。
3. GitHub 版 index.html：把本體包成獨立網頁——
   `<!doctype html>\n<html lang="zh-Hant">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<meta name="description" content="台北捷運每日輿情彙整：營運、工程路網、票務、安全與社群熱議。">\n` + 本體中 `<header class="masthead">` 之前的部分（title、link、style）+ `\n</head>\n<body>\n` + 從 `<header class="masthead">` 到 `</script>` 的部分 + `\n</body>\n</html>\n`。
4. 驗證：用 node 把 LOG 陣列抽出來 parse，確認語法正確、天數 ≤14、今日則數與 metrics 相符、日期不重複且由新到舊、每則 url 為 http(s)；確認 index.html 裡 `</head>`、`<body`、`</body>` 各只出現一次；確認今天這一筆的 summary 與 items 沒有「DNS」「可連線網域」之類的連線失敗說明。再用 Playwright + 預裝 Chromium 開 index.html 截圖，確認版面沒跑掉、日期切換與雙日比對正常（今天 items 為空時頁面也要能正常顯示）。啟動方式：`chromium.launch({executablePath:'/opt/pw-browsers/chromium-<版號>/chrome-linux/chrome'})`（先 `ls /opt/pw-browsers/` 取實際版號目錄）；node 找不到 playwright 時 `npm install playwright --no-audit --no-fund`，**不要執行 playwright install**。字型載入失敗的 console 錯誤可忽略。

【步驟六：部署到 GitHub Pages 與 Cloudflare】
1. 取得 cjw9223233/mrt-log 的工作目錄：session 的工作目錄若已經是這個 repo（`git remote get-url origin` 含 cjw9223233/mrt-log）就直接使用，不要重新 clone；1-B 已 clone 就沿用；都沒有才 clone。先 `git fetch origin main` 再 `git merge --ff-only origin/main`，確保是從最新的 main 往下做。然後覆寫 index.html，並確保根目錄有空檔 .nojekyll。repo 內的其他檔案（tools/、wrangler.jsonc、README.md、ops/、docs/）一律不要動。
2. `git config user.name "Claude"`、`git config user.email "noreply@anthropic.com"`，只 `git add index.html .nojekyll`，commit 訊息「日誌更新 YYYY-MM-DD」。
3. 用 `git ls-remote --symref origin HEAD` 確認預設分支（目前應為 main），再 `git push origin HEAD:main`（若預設分支已改名，改推該分支）。session 若另外指定了工作分支（例如 claude/ 開頭），同一個 commit 也用 `git push -u origin HEAD:<工作分支>` 推上去，避免結束前的檢查卡住。**不要在指令、檔案或輸出中放任何 token**；憑證由本排程所連結的 GitHub 授權自動提供。
4. 若 push 到 main 被拒（例如分支權限檢查），改推 `git push origin HEAD:claude/pages --force`，並在通知中說明兩件事：請使用者到 https://github.com/cjw9223233/mrt-log/settings/pages 把 Branch 改成 claude/pages（只需改一次；若已是 claude/pages 就不必提醒）；以及 Cloudflare 只跟 main，這次不會更新，需要把該 commit 合併回 main。
5. 若出現「not in this session's authorized repository set」之類的 403 → 代表 repo 尚未加進此排程的 repository 設定；不要嘗試其他繞過方式，照常完成步驟七，並在通知中說明：請到 https://claude.ai/code/routines → 北捷輿情日誌 → Edit → Select repositories 加入 cjw9223233/mrt-log。
6. push 成功後等約 60 秒，用 WebFetch 分別開 https://cjw9223233.github.io/mrt-log/ 與 https://mrt-log.cjw-9223233.workers.dev/ ，確認「最後更新」時間戳已是今天（WebFetch 失敗時同樣改用 `curl -sS -L -m 30` 取回 HTML 再比對）。快取或建置可能延遲至 10 分鐘，未更新不算失敗，只在通知中註記；兩種方法都打不開時，只在通知中註記「未能複核」，不要重試其他繞過方式。

【步驟七：發布 Artifact】
用 Artifact 工具發布 /root/mrt_log.html，**務必帶上 url 參數指向 https://claude.ai/code/artifact/10582dca-0c98-466c-b0b1-25e995d13ee0** ，不要省略 url，否則會另開新網址。
- 走 1-A → 正常發布。
- 走 1-B → 發布會因「未讀取線上版」被拒；使用者已授權此時改用 force:true 覆蓋（GitHub 版即為權威版本）。
- 仍失敗 → 不要另開新網址；用 SendUserFile 送出當日 HTML 檔，並在通知中說明。

【步驟八：通知】
需要通知時，用 PushNotification 送出今日摘要，內容放在 <routine_summary> 標籤內：第一句寫今天最值得注意的一件事，接著條列各分類重點（每則含來源與簡短說明）、標註明顯爭議或熱議話題，最後附上三個網址：https://cjw9223233.github.io/mrt-log/ 、 https://mrt-log.cjw-9223233.workers.dev/ 與 artifact 網址。
- 一定要通知：GitHub 部署或 artifact 發布任一失敗、改推了備用分支、驗證沒過而未發布。一併說明原因與修法。
- 應該通知：當天有 hot:true 的爭議題，或有值得注意的新事件。
- 可以不通知：當天輿情平淡（含 0 則）且部署都成功。仍需更新網頁。
- 來源讀不到、公開網址未能複核：有發通知時附在最後，列出讀不到的網域，並提醒到 https://claude.ai/code/routines → 北捷輿情日誌 的環境網路設定加入這些網域。當天沒有其他通知理由時，只在週一為此發一則簡短提醒，其餘日子不為此單獨通知。
````
<!-- PROMPT:END -->

---

## 4. 修改指令的流程

1. **改這份檔案**：只改第 3 節原文區塊內的文字。若改動影響第 1、2 節的設定或步驟表，一併更新。
2. **commit**：訊息建議用 `排程指令：<改了什麼>`，與每日自動提交的「日誌更新 YYYY-MM-DD」區分。
3. **同步到線上**，二擇一：
   - 到 <https://claude.ai/code/routines>，選「北捷輿情日誌」，按 Edit，把第 3 節原文整段貼上後儲存。
   - 在 Claude Code 中請 Claude 用 `RemoteTrigger update` 更新 `trig_012mqdDyG5g8pjmqgSEJwKpM` 的指令，內容取自本檔第 3 節。
4. **手動觸發一次**：在後台按 Run，或請 Claude 執行 `RemoteTrigger run`。執行過程可在後台查看，或用 `RemoteTrigger list_runs` 與 `get_run_log` 查看。
5. **確認結果**：repo 有新的「日誌更新」commit；三個網址（Artifact、GitHub Pages、Cloudflare）的「最後更新」都是今天；頁面版面與日期切換正常。
6. **補變更紀錄**：在第 7 節加一筆。

> 修改時要特別小心的地方：
> - 指令中的 Artifact 網址、repo 路徑與兩個公開網址寫死在多處（固定產出目標、步驟一、步驟六、步驟七、步驟八），改一處要全部改。
> - 步驟二的「收錄門檻」決定頁面每天有幾則。放寬門檻（例如恢復則數下限）會讓排程拿沒有新進展的舊議題湊數，2026-11-15 改版前的 14 天裡，94 則有 62 則的來源網址是前幾天用過的。
> - 「只保留最近 14 天」與「TRACK 維持 8–12 個」直接影響頁面寬度與檔案大小。
> - 步驟四是防止 AI 每天重新設計版面的護欄，不建議放寬。

---

## 5. 檢查 repo 版與線上版是否一致

建議每次修改後，以及每月抽查一次。

**方法一（後台）**：在 <https://claude.ai/code/routines> 開啟排程的 Edit 畫面，把指令全文複製下來，和第 3 節原文比對。

**方法二（Claude Code）**：請 Claude 執行下列步驟：

1. 用 `RemoteTrigger get` 取得 `trig_012mqdDyG5g8pjmqgSEJwKpM`，取出 `derived_state.prompt`，存成 `live.txt`。
2. 用以下指令取出本檔原文區塊並比對：

```bash
python - <<'EOF'
import re
md = open("ops/routine-prompt.md", encoding="utf-8").read()
repo = re.search(r"<!-- PROMPT:START -->\n````text\n(.*)\n````\n<!-- PROMPT:END -->", md, re.S).group(1)
live = open("live.txt", encoding="utf-8").read()
print("一致" if repo == live else "不一致")
EOF
```

---

## 6. 待確認事項

以下是收錄指令時在設定中發現的疑點，目前都**沒有**造成執行失敗，只列出來供後續處理。

| 項目 | 觀察 | 影響 | 建議 |
|---|---|---|---|
| 工具清單 | 指令使用 Artifact、PushNotification、SendUserFile，但這三個都不在 `allowed_tools` 中 | 目前每天都成功，推測是排程內建工具；若平台日後改為嚴格限制，步驟七、八可能失效 | 下次調整排程時一併確認，必要時把工具加入清單 |
| 產出分支 | 排程設定的產出分支是 `claude/brave-johnson`，但指令要求推送 `main`。2026-11-14 的執行中，session 的工作分支實際是 `claude/brave-johnson-zm1fv8`，結束前的檢查要求把提交也推到這條分支，所以同一個提交會同時出現在 `main` 與工作分支 | repo 會多出內容與 `main` 重複的 `claude/…` 分支，造成混淆 | 確認這些分支是否需要保留；不需要就定期刪除，或從排程設定中移除產出分支 |
| 基底優先順序 | 步驟 1-A 以 Artifact 為主要基底，GitHub 只是備援 | 只在 GitHub 手動修改 `index.html` 的話，下次排程可能用 Artifact 舊版蓋掉 | 人工修改 GitHub 後，請 Claude 依新版 `index.html` 覆蓋發布 Artifact，讓兩邊一致 |

| Cloudflare 的檢查要等同步後才生效 | 2026-11-15 的修改版已把 Cloudflare 納入固定產出目標、步驟六的時間戳檢查與步驟八的通知，但線上排程還是舊版 | 同步前，Cloudflare 建置失敗不會被發現，也不會推播 | 照第 4 節把修改版同步到線上；並把 `mrt-log.cjw-9223233.workers.dev` 加入環境的連線名單，否則檢查只會回報「未能複核」 |
| 備用分支不會更新 Cloudflare | 步驟六在 `main` 被拒時改推 `claude/pages`，Cloudflare 只跟 `main`。修改版會在通知中提醒這一點 | 發生時 GitHub Pages 可切換分支補救，Cloudflare 版會停在舊內容 | 發生時把提交合併回 `main`，或到 Cloudflare 主控台暫時改部署分支 |
| 對外連線名單 | 2026-11-14 執行時，下列網域因不在環境的連線名單而無法解析：`www.metro.taipei`、`news.ltn.com.tw`、`www.cna.com.tw`、`www.pttweb.cc`、`www.ftnn.com.tw`、`n.yam.com`、`cjw9223233.github.io`、`mrt-log.cjw-9223233.workers.dev`。**2026-11-15 已加入環境的 Allowed domains 並驗證**：從 Bash 用 `curl` 八個網域都回 200，兩個公開頁讀得到且「最後更新」與 repo 一致。但 **WebFetch 工具在同一個 session 裡仍回 `getaddrinfo ENOTFOUND`**，推測它不走環境的連線名單，因此修改版指令要求 WebFetch 失敗時改用 `curl` | 設定問題已解決。剩下的風險是排程若只用 WebFetch，仍會誤判為讀不到 | 修改版指令（尚未同步到線上）已寫入 curl 備援；同步後下一次排程執行時，確認通知與頁面沒有「讀不到」的說明 |

---

## 7. 變更紀錄

| 日期 | 變更 |
|---|---|
| 2026-09-21 | 建立排程 |
| 2026-10-05 | 指令首次收進版控（內容與線上版逐字相同，未修改） |
| 2026-11-14 | 新增 Cloudflare 部署（`tools/build-site.sh`、`wrangler.jsonc`），由 push 到 `main` 觸發。**指令原文未修改**，線上排程不需同步 |
| 2026-11-15 | **指令原文改版（尚未同步到線上）**：(1) 取消「每天 6–13 則」的下限，只收近 2 天有新進展且日期可確認的條目，長期未結事項改放背景議題；(2) 連線失敗只寫進通知，不寫進頁面；(3) 組檔前先刪除本體內重複的 `</head>`、`<body>`，並加入對應驗證；(4) 納入 Cloudflare：固定產出目標、部署後檢查、通知網址、備用分支提醒；(5) git 步驟改為沿用工作目錄、`git ls-remote --symref`、`git push origin HEAD:main`，只提交 `index.html` 與 `.nojekyll`；(6) 天數改用具體日期或以 `date` 計算；(7) 通知規則分成一定通知、應該通知、可以不通知三級 |
| 2026-11-15 | 指令原文再改（仍未同步到線上）：新增「WebFetch 失敗時改用 `curl`」的讀取順序與禁止偽裝 User-Agent 的限制，步驟六的時間戳確認同步改用同一方法。原因：環境連線名單設定完成後實測，`curl` 八個網域都通，WebFetch 仍 DNS 解析失敗 |
| 2026-11-15 | 頁面配色改為四色色盤（`--lc-1`～`--lc-4`，定義在 `index.html` 與 Artifact 的 `<style>` 開頭），淺色與深色模式的語意色都由這四色延伸；紅色（爭議、安全與治安）因語意需要保留，但調成較低彩度。**與指令原文無關，不需同步到線上排程**；排程只改資料，會沿用基底的配色 |
| 2026-11-15 | 第 1、2 節補上發布點 C 與其網址；第 6 節新增 Cloudflare、備用分支、對外連線名單三項待確認事項，並更新產出分支的觀察 |
