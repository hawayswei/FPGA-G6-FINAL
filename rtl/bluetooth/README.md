# bluetooth 子系統

| 項目 | 內容 |
|---|---|
| 負責人 | 整合者 |
| 狀態 | 已模擬（`tb_bt_link` PASS）；上板測試待做 |
| 模組前綴 | `bt_` |
| 時脈 | 125 MHz `clk_i` |
| 重置 | 同步、低電位有效 `rst_n_i` |

## 功能

和課程藍牙模組以 UART（9600 8N1）通訊：接收手機的模式與身高指令，把事件用文字送到手機。

## 模組清單

| 檔案 | 模組 | 用途 |
|---|---|---|
| `bt_uart_rx.v` | `bt_uart_rx` | UART 接收。只在完整且停止位元正確時輸出 `valid_o` |
| `bt_uart_tx.v` | `bt_uart_tx` | UART 傳送 |
| `bt_cmd_parser.v` | `bt_cmd_parser` | 指令解析：`A`／`E`／`S` 模式，`H165` 身高。忽略 CR、LF 與未知字元 |
| `bt_msg_tx.v` | `bt_msg_tx` | 依請求位元送出文字訊息（結尾 CR LF）。文字是參數 |

## 對外介面

| 埠名 | 方向 | 位寬 | 說明 |
|---|---|---|---|
| `rx_i`（`bt_uart_rx`） | 輸入 | 1 | 接藍牙模組 TXD |
| `tx_o`（`bt_msg_tx`） | 輸出 | 1 | 接藍牙模組 RXD |
| `mode_o` | 輸出 | 2 | 0 成人、1 老人、2 運動 |
| `height_o` | 輸出 | 8 | 身高（公分） |
| `cfg_update_o` | 輸出 | 1 | 設定被接受的脈衝 |
| `req_i`（`bt_msg_tx`） | 輸入 | 8 | 第 n 位元的脈衝＝送第 n 則訊息 |

指令字母、訊息文字、事件對應的修改位置見 `docs/TUNING.md`。

## 需要的腳位

Pmod A 下排：FPGA TX = W18（第 9 腳，接模組 RXD）、FPGA RX = W19（第 10 腳，接模組 TXD），見 `constr/bt.xdc`。和 Lab 2–4 的位置不同。
