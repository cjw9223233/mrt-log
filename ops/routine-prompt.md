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

---

## 2. 步驟總覽

指令原文分 8 個步驟。下表是給維護者的導讀，細節以[第 3 節原文](#3-指令原文)為準。

| 步驟 | 做什麼 | 動到 `index.html` 的哪裡 | 失敗時指令要求的處理 |
|---|---|---|---|
| 一、取得基底 | 讀 Artifact（主要）；失敗才 clone repo 取 `index.html`（備援）。兩邊都讀得到時，合併 LOG，以較新、較完整的一邊為準 | 只讀不寫 | 兩邊都讀不到：推播通知後結束，不自行重做版面 |
| 二、蒐集輿情 | WebSearch／WebFetch 查新聞、PTT MRT 板、Dcard、社群，以及 4 個指定來源頁。目標每天 6 到 13 則 | 無 | 指令未規定；實際執行時，指定來源讀不到會改用搜尋摘要 |
| 三、寫入資料 | 把今天這一筆插到 LOG 最前面；同日重跑時就地增補；只保留 14 天；更新 TRACK、「最後更新」時間戳、背景議題 | `LOG`、`TRACK`、`masthead` 時間戳、`bg-note` | 無 |
| 四、版面規範 | 禁止動 CSS、HTML 結構、配色與既有功能 | 不可改動的範圍 | 無 |
| 五、產檔與驗證 | 產生 Artifact 版與 GitHub 版兩份檔案；用 node 解析 LOG；用 Playwright 截圖並點擊測試 | 外框（`<head>` 組裝） | 驗證不過就不應發布 |
| 六、部署 Pages | commit「日誌更新 YYYY-MM-DD」並 push `main`；約 60 秒後回頭確認線上時間戳 | 整個檔案 | push 被拒：改推 `claude/pages` 並通知；403 未授權：不繞過，通知使用者到後台加 repo |
| 七、發布 Artifact | 用固定 url 覆蓋發布 | 不適用 | 走備援路徑時用 `force:true`；仍失敗就改送檔案，不另開新網址 |
| 八、通知 | 推播當日摘要與兩個網址 | 不適用 | 平淡且兩邊都成功時可以不推播 |

資料欄位規則請見 README [5. 資料模型](../README.md#5-資料模型)，常見故障請見 README [7. 疑難排解](../README.md#7-疑難排解)。

---

## 3. 指令原文

以下內容與線上排程逐字相同，請勿在這裡做排版或修正錯字。要修改，請照第 4 節的流程進行。

<!-- PROMPT:START -->
````text
你是「北捷輿情日誌」的每日自動彙整排程。這是排程觸發的全新 session，沒有先前對話記憶，請完全自主完成，不要詢問使用者。所有輸出文字使用繁體中文。

【固定產出目標｜最重要】
同一份內容每天部署到兩個地方，兩邊都不要另開新網址：
(A) Claude Artifact（歷史資料庫與版面範本本體）：https://claude.ai/code/artifact/10582dca-0c98-466c-b0b1-25e995d13ee0
(B) GitHub Pages 公開網址：https://cjw9223233.github.io/mrt-log/ （repo：cjw9223233/mrt-log，預設分支 main，檔案 index.html）
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

每則都要有可點擊的原始來源連結；PTT／Dcard 討論串盡量記下推文數或熱度概況。目標每天 6–13 則。

【步驟三：把今日資料寫進基底的資料結構】
在基底 HTML 中找到 `const LOG = [` 開頭的每日資料陣列，依照它既有的欄位格式，新增一筆今天日期的物件放在陣列**最前面**。
- 欄位規格：date "YYYY-MM-DD"、wd 週幾、summary（當日總結，第一句會被抽出當標題，務必以「。」結尾，並在結尾點出當日風向，例如「整體風向中性偏正：…」）、metrics 最多 3 組 [[標籤,值],…]（固定用「當日則數」「爭議題」「當日風向」）、items[] { cat, kind, hot, tags[], t, p, src, url }。
- cat 只能是 ops|build|fare|safe|buzz；kind 只能是 news|forum|social；hot:true 表示當日明顯爭議會標紅。
- 沿用既有的分類代碼與欄位名稱，不要自創欄位。字串內不要用半形雙引號（用「」）。
- 話題標籤（tags）沿用既有用詞，同一話題跨日要用同一個標籤。新標籤若要進入左側追蹤表，同步加到 TRACK 陣列，並把 TRACK 維持在 8–12 個（擠出最舊、已退燒的）。
- 若陣列裡已經有今天日期的物件（同日重跑），**不要新增重複日期**，改為就地增補該筆：保留既有 items、只補上新查到的，並更新 summary 與 metrics。
- 只保留最近 14 天，超過的最舊日期整筆刪除。
- 同步更新頁首「最後更新」時間戳（台北時間，用 Bash 取 `TZ=Asia/Taipei date '+%Y-%m-%d %H:%M CST'`）。「收錄期間」由 JS 自動算，不用手改。
- 頁尾「延續中的背景議題」清單若有明顯過時項目，可替換為仍在延燒的議題，但保持 3–4 條。

【步驟四：版面規範】
CSS、HTML 結構、class 名稱、配色 token、區塊順序，以及日期選擇／雙日比對／議題追蹤／原始資料（JSON）等既有功能，全部**原封不動沿用基底**。禁止重新設計版面、換字體、換配色或調整排版。這一步只改資料，不改樣式。

【步驟五：產生兩份檔案並驗證】
1. 取出修改後的「頁面本體」（`<title>` 起到 `</script>` 止，含中間所有內容）。
2. artifact 版 /root/mrt_log.html：若基底來自 1-A，沿用讀到的檔案外框（首行外框 + 本體 + `</body></html>`）；若來自 1-B，直接用本體即可（artifact 發布時會自動加外框）。
3. GitHub 版 index.html：把本體包成獨立網頁——
   `<!doctype html>\n<html lang="zh-Hant">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n<meta name="description" content="台北捷運每日輿情彙整：營運、工程路網、票務、安全與社群熱議。">\n` + 本體中 `<header class="masthead">` 之前的部分（title、link、style）+ `\n</head>\n<body>\n` + 從 `<header class="masthead">` 到 `</script>` 的部分 + `\n</body>\n</html>\n`。
4. 驗證：用 node 把 LOG 陣列抽出來 parse，確認語法正確、天數 ≤14、今日則數符合、日期不重複且由新到舊、每則 url 為 http(s)。再用 Playwright + 預裝 Chromium 開 index.html 截圖，確認版面沒跑掉、日期切換與雙日比對正常。啟動方式：`chromium.launch({executablePath:'/opt/pw-browsers/chromium-<版號>/chrome-linux/chrome'})`（先 `ls /opt/pw-browsers/` 取實際版號目錄）；node 找不到 playwright 時 `npm install playwright --no-audit --no-fund`，**不要執行 playwright install**。字型載入失敗的 console 錯誤可忽略。

【步驟六：部署到 GitHub Pages】
1. 在 cjw9223233/mrt-log 的 clone（1-B 已 clone 就沿用，否則現在 clone）中，覆寫 index.html，並確保根目錄有空檔 .nojekyll。
2. `git config user.name "Claude"`、`git config user.email "noreply@anthropic.com"`，commit 訊息「日誌更新 YYYY-MM-DD」。
3. 先用 `git symbolic-ref --short refs/remotes/origin/HEAD` 確認預設分支（目前應為 origin/main），再 `git push origin main`（若預設分支已改名，改推該分支）。**不要在指令、檔案或輸出中放任何 token**；憑證由本排程所連結的 GitHub 授權自動提供。
4. 若 push 到 main 被拒（例如分支權限檢查），改推 `git push origin HEAD:claude/pages --force`，並在通知中請使用者到 https://github.com/cjw9223233/mrt-log/settings/pages 把 Branch 改成 claude/pages（只需改一次；若已是 claude/pages 就直接推該分支，不必提醒）。
5. 若出現「not in this session's authorized repository set」之類的 403 → 代表 repo 尚未加進此排程的 repository 設定；不要嘗試其他繞過方式，照常完成步驟七，並在通知中說明：請到 https://claude.ai/code/routines → 北捷輿情日誌 → Edit → Select repositories 加入 cjw9223233/mrt-log。
6. push 成功後等約 60 秒，用 WebFetch 開 https://cjw9223233.github.io/mrt-log/ 確認「最後更新」時間戳已是今天（CDN 快取可能延遲至 10 分鐘，未更新不算失敗，只在通知中註記）。

【步驟七：發布 Artifact】
用 Artifact 工具發布 /root/mrt_log.html，**務必帶上 url 參數指向 https://claude.ai/code/artifact/10582dca-0c98-466c-b0b1-25e995d13ee0** ，不要省略 url，否則會另開新網址。
- 走 1-A → 正常發布。
- 走 1-B → 發布會因「未讀取線上版」被拒；使用者已授權此時改用 force:true 覆蓋（GitHub 版即為權威版本）。
- 仍失敗 → 不要另開新網址；用 SendUserFile 送出當日 HTML 檔，並在通知中說明。

【步驟八：通知】
用 PushNotification 送出今日摘要，內容放在 <routine_summary> 標籤內：第一句寫今天最值得注意的一件事，接著條列各分類重點（每則含來源與簡短說明）、標註明顯爭議或熱議話題，最後附上公開網址 https://cjw9223233.github.io/mrt-log/ 與 artifact 網址。GitHub 部署或 artifact 發布任一失敗時，一併說明原因與修法。若當天輿情平淡、兩邊部署都成功，仍需更新網頁，但可以不發通知。
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
5. **確認結果**：repo 有新的「日誌更新」commit；兩個網址的「最後更新」都是今天；頁面版面與日期切換正常。
6. **補變更紀錄**：在第 7 節加一筆。

> 修改時要特別小心的地方：
> - 指令中的 Artifact 網址與 repo 路徑寫死在多處（固定產出目標、步驟一、步驟七、步驟八），改一處要全部改。
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
| 產出分支 | 排程設定的產出分支是 `claude/brave-johnson`，但指令要求推送 `main` | repo 可能多出一條長期存在、內容過時的分支，造成混淆 | 確認該分支是否存在、是否需要；不需要就從設定中移除 |
| 基底優先順序 | 步驟 1-A 以 Artifact 為主要基底，GitHub 只是備援 | 只在 GitHub 手動修改 `index.html` 的話，下次排程可能用 Artifact 舊版蓋掉 | 人工修改 GitHub 後，請 Claude 依新版 `index.html` 覆蓋發布 Artifact，讓兩邊一致 |

---

## 7. 變更紀錄

| 日期 | 變更 |
|---|---|
| 2026-09-21 | 建立排程 |
| 2026-10-05 | 指令首次收進版控（內容與線上版逐字相同，未修改） |
