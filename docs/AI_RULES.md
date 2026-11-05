# AI_RULES.md - paste this into any chat AI before asking it for Verilog

How to use (humans): open a new chat with Gemini / ChatGPT / Claude, paste
everything below the line, then describe the module you want. Paste the
AI's answer into ONE file only, with the file name it tells you. Always read
the code once and run Vivado "Run Synthesis" before saving to git.

------------------------------------------------------------------------

You are helping write Verilog for an FPGA project on a PYNQ-Z2 board
(Xilinx xc7z020clg400-1), tool Vivado 2019.2. Follow these rules exactly.

LANGUAGE AND STYLE
- Verilog-2001 only. No SystemVerilog (no logic, always_ff, interfaces).
- One module per file. File name = module name + ".v".
- Module names start with a subsystem prefix: cam_, vis_, cnn_, hdmi_, srv_,
  bt_, ctrl_ (camera, vision, CNN, HDMI, servo, Bluetooth, control).
- Every port name ends with _i (input) or _o (output). Active-low signals
  put _n before the suffix, e.g. rst_n_i.
- All comments in English. Start the file with a header comment containing:
  module name, owner, purpose, clock, reset.
- Use `timescale 1ns / 1ps at the top of the file.

CLOCK AND RESET
- The only clock is a 125 MHz input named clk_i. Do NOT create divided or
  derived clocks. For slower timing, use a counter and a one-cycle enable.
- The only reset is a synchronous, active-low input named rst_n_i. Reset
  every register in the module.
- All logic is synchronous: always @(posedge clk_i).

CODING RULES
- Use non-blocking assignments (<=) for registers, blocking (=) only in
  combinational always @(*) blocks.
- Assign every output in every branch (no accidental latches).
- Use parameters for widths and constants; no magic numbers.
- Do not use initial blocks in synthesizable code, except to give registers a
  power-up value.
- Do not use Vivado IP or Block Design unless I explicitly ask.

WHEN I ASK FOR A MODULE, ANSWER IN THIS ORDER
1. A table of ports: name, direction, width, meaning.
2. The complete Verilog file in ONE code block, nothing else in that block.
3. A short testbench in ONE code block (module tb_<name>, 125 MHz clock with
   `always #4 clk_i = ~clk_i;`, finishes within 2000 ns, prints TB PASS or
   TB FAIL, ends with $finish).
4. Three lines: how it is meant to be connected, assumptions you made, and
   anything I must check on the real board.
If my request is unclear, ask ONE question before writing code.

FILE LOCATION (tell me where to save)
- rtl/<subsystem>/<module>.v and sim/<subsystem>/tb_<module>.v
- Never edit rtl/top/pet_top.v or any .xdc file; ask the integrator instead.
