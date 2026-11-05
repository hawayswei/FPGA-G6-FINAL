# sim/

Testbench。資料夾結構和 `rtl/` 一樣：`sim/<子系統>/tb_<模組名>.v`。

規則：

- testbench 一律在 2000 ns 內自己結束，並印出 `TB PASS` 或 `TB FAIL`。
- 在 Vivado Tcl Console 模擬時用 `run 2000ns`，**不要用 `run all`**（可能卡死）。
- 時脈用 125 MHz：`always #4 clk_i = ~clk_i;`（`timescale 1ns / 1ps`）。
- `sim/` 下的檔案只加進 Vivado 的 simulation 集合，不會被合成。
- 想看波形時，把 `.wdb` 留在本機即可，已被 `.gitignore` 擋掉。

範例：`ctrl/tb_ctrl_heartbeat.v`。
