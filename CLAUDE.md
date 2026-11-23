# CLAUDE.md - rules for AI agents working in this repo

Read this file first. It is the machine-facing twin of README.md (written for
humans in Traditional Chinese). If the two ever disagree, stop and ask the
human.

## Project

- FPGA course final project, group 6: "Invisible Guardian" (working title,
  may change), a wearable elder-care system on a PYNQ-Z2 board
  (xc7z020clg400-1). Pure PL, all Verilog, PS unused. No machine learning.
- Function: fall detection from 3-axis acceleration only (PmodACL2 / ADXL362,
  SPI) with a personalized threshold from user mode and height (sent by phone
  over Bluetooth); on a fall the OLED asks "Are you OK?" and the wearer has
  **10 s** to press a button to cancel, otherwise ALARM latches and a Bluetooth
  alert goes to the phone; manual SOS by button; Pmod TMP3 (I2C) body
  temperature shown on the RGB LED and OLED.
- Subsystems: accelerometer SPI, fall detection, temperature I2C, Bluetooth
  UART, OLED, control FSM (10 s timer, ALARM latch, buttons).
- Proposal: `FPGA期末專題提案書.pdf` (outside the repo). The 10 s timeout is
  decided; page 6 of the proposal still says 5 s and is a typo.
- Toolchain: Vivado 2019.2 on Windows 11, same version for the whole team.
  Typical install: `D:/Xilinx/Vivado/2019.2/bin/vivado.bat`.
- Team of 3. The human maintainer is the **integrator**. Teammates are
  beginners with git and use a GUI (GitKraken or GitHub Desktop) plus a chat AI.
- History: the earlier "desktop pet" topic was dropped; its camera/vision/CNN/
  HDMI/servo folders were removed. The generic skeleton (top, reset sync,
  heartbeat, scripts, AI rules) was kept and renamed for this project.

## Repo map (current)

| Path | Content | Who edits |
|---|---|---|
| `rtl/top/` | `guardian_top.v` (top level wiring) | integrator only |
| `rtl/<subsystem>/` | synthesizable Verilog, one folder per subsystem | that subsystem's owner |
| `sim/<subsystem>/` | testbenches, mirror of `rtl/` | owner |
| `constr/` | `.xdc` files, split by function | integrator only |
| `ip/` | single-IP `.xci` files only | integrator only |
| `scripts/` | Tcl and `.bat` helpers (`capture.tcl` records trials through the ILA) | integrator only |
| `tools/` | Python: trial statistics, bit-exact fall model, test vector generator | integrator |
| `data/trials/` | recorded trials, one small CSV each (`_report/` is generated, ignored) | anyone |
| `docs/` | spec, manuals, templates, AI rules | anyone, keep tidy |

Subsystem folders (proposed, not final): `accel`, `fall`, `temp`, `bluetooth`,
`oled`, `ctrl`. Every subsystem folder must contain a `README.md` (copy
`docs/templates/SUBSYSTEM_README.md`) stating owner, ports, clocks, status.

## Hard rules (never violate)

1. Never force-push. Never `git reset --hard`, `git clean -fd`, or delete
   branches without the human explicitly asking in this session.
2. Never commit: `vivado_prj/`, `build/`, `*.bit`, `*.xpr`, videos, datasets,
   logs. `.gitignore` covers these; do not use `git add -f`.
3. Only the integrator changes `rtl/top/guardian_top.v`, `constr/*.xdc`, `ip/`,
   `scripts/`. If you are working for a teammate and need such a change, write
   the request into the PR description or tell the human; do not edit.
4. Teammates push only to their own branch (`member-b`, `member-c`; names may
   change). Only the integrator merges into `main`.
5. On any merge conflict: stop, show the human the conflicting files, and wait.
   Do not resolve a conflict for a teammate's file without being told.
6. Do not use Vivado Block Design. IP cores only as single `.xci` in `ip/`.
7. Never ask for, print, or store GitHub tokens or passwords. Authentication
   is done by the human with `gh auth login` in a browser.

## Verilog conventions

- Verilog-2001 only (`.v`). No SystemVerilog.
- One module per file; file name = module name.
- Module names carry the subsystem prefix: `acl_`, `fall_`, `tmp_`, `bt_`,
  `oled_`, `ctrl_`. Top is `guardian_top`.
- Ports end in `_i` (input) or `_o` (output). Active-low signals end in `_n`
  before the direction suffix, for example `rst_n_i`.
- One clock: 125 MHz `sysclk_i`. Slower rates use clock enables, not
  derived clocks. SPI/I2C clocks are generated as enables, not as clocks.
- One reset: synchronous, active low `rst_n`, generated once in `guardian_top` by
  `ctrl_reset_sync` and passed to every module.
- Comments and identifiers in English. Every file starts with a header
  comment: module, owner, purpose, clock, reset.
- Do not leave latches; assign every output in every branch.

## Git conventions

- Branches: `main` (integrator merges only), `member-a` (the integrator's own
  editing branch), `member-b`, `member-c` (teammates). Before writing files
  for the human, check which branch is checked out (`.git/HEAD`); the working
  folder always reflects the current branch.
- Commit messages in English: `[area] what changed`, for example
  `[acl] add SPI controller`. Areas: acl, fall, tmp, bt, oled, ctrl, top,
  constr, ip, scripts, docs.
- Milestone tags (integrator only): `proposal-v1`, `video-v1`, `demo-v1`,
  `report-v1`. Deadlines may move; add new tags instead of freezing `main`.
- `main` must always build. Before merging a branch into `main`, run
  `scripts/check.bat` (or `vivado -mode batch -source scripts/check.tcl`)
  and confirm `build/check_result.txt` says PASS.
- In a PR description state: what changed, whether it was synthesized, and
  whether it was tested on the board.

## Working notes (learned the hard way)

- Repo path must be ASCII-only and short (for example `D:/FPGA/FPGA-G6-FINAL`).
- In a Vivado MCP/Tcl session do not run `run all` on a testbench (it can hang
  the Tcl channel); use `run 2000ns`. A `$` can be dropped when writing files
  through Tcl; re-read the written file.
- Program the board over USB-JTAG. The agent cannot see the physical LEDs;
  ask the human to report board behavior.
- Claude cannot run git. Files are written to the working folder, then the
  human commits and pushes with the GUI.

## Spec and deadlines

Course statements are in `docs/spec/`. Key dates: team registration 11/8,
proposal 11/15, intro video 12/7, exhibition 12/14, written report 12/21.
Material subsidy is limited (about NT$1,500 per group); do not suggest
purchases without the human confirming with the TA.

## When unsure

Ask the human. A wrong git action is expensive; a question is cheap.
