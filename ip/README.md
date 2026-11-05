# ip/

Vivado IP 核。**只有整合者編輯這個資料夾。**

- 只存單一 IP 的 `.xci`（例如 Clock Wizard、Block RAM），放在各自的子資料夾，例如 `ip/clk_wiz_pix/clk_wiz_pix.xci`。
- 不存 IP 產生的輸出檔（`.dcp`、`.v` wrapper、`.xdc` 等），這些由 `create_project.tcl` 在每個人的電腦上重新產生。
- **不使用 Block Design。**
- 新增 IP 時，同時在對應子系統的 README 記錄用途與參數。
