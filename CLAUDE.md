# CLAUDE.md - rules for AI agents working in this repo

Read this file first. It is the machine-facing twin of README.md (which is
written for humans in Traditional Chinese). If the two ever disagree, stop and
ask the human. Also read `docs/AI_RULES.md` before writing any Verilog.

## Project

- FPGA course final project, group 6: a desktop pet (working title) on a
  PYNQ-Z2 board (xc7z020clg400-1). Pure PL, all Verilog, PS unused.
- Subsystems: camera capture, vision (staged: background subtraction +
  centroid -> rule-based rock-paper-scissors -> small CNN), HDMI HUD,
  pan-tilt / arm servos, Bluetooth UART, mode controller.
- Toolchain: Vivado 2019.2 on Windows 11, same version for the whole team.
  Typical install: `D:/Xilinx/Vivado/2019.2/bin/vivado.bat`.
- Team of 3. The human maintainer is the **integrator**. Teammates are
  beginners with git and may use only GitHub Desktop and a chat AI.

## Repo map

| Path | Content | Who edits |
|---|---|---|
| `rtl/top/` | `pet_top.v` (top level wiring) | integrator only |
| `rtl/<subsystem>/` | synthesizable Verilog, one folder per subsystem | that subsystem's owner |
| `sim/<subsystem>/` | testbenches, mirror of `rtl/` | owner |
| `constr/` | `.xdc` files, split by function | integrator only |
| `ip/` | single-IP `.xci` files only | integrator only |
| `ml/` | CNN training (Python) and small quantized weights | ML owner |
| `scripts/` | Tcl and `.bat` helpers | integrator only |
| `docs/` | spec, manuals, templates, AI rules | anyone, keep tidy |

Subsystem folders: `camera`, `vision`, `cnn`, `hdmi`, `servo`, `bluetooth`,
`ctrl`. Every subsystem folder must contain a `README.md` (copy
`docs/templates/SUBSYSTEM_README.md`) stating owner, ports, clocks, status.

## Hard rules (never violate)

1. Never force-push. Never `git reset --hard`, `git clean -fd`, or delete
   branches without the human explicitly asking in this session.
2. Never commit: `vivado_prj/`, `build/`, `*.bit`, `*.xpr`, videos, datasets,
   logs. `.gitignore` covers these; do not use `git add -f`.
3. Only the integrator changes `rtl/top/pet_top.v`, `constr/*.xdc`, `ip/`,
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
- Module names carry the subsystem prefix: `cam_`, `vis_`, `cnn_`, `hdmi_`,
  `srv_`, `bt_`, `ctrl_`. Top is `pet_top`.
- Ports end in `_i` (input) or `_o` (output). Active-low signals end in `_n`
  before the direction suffix, for example `rst_n_i`.
- One clock: 125 MHz `sysclk_i`. Slower rates use clock enables, not
  derived clocks. Exceptions (camera pixel clock, HDMI pixel clock) must come
  from a Clock Wizard IP and be documented in the subsystem README.
- One reset: synchronous, active low `rst_n`, generated once in `pet_top` by
  `ctrl_reset_sync` and passed to every module.
- Comments and identifiers in English. Every file starts with a header
  comment: module, owner, purpose, clock, reset.
- Do not leave latches; assign every output in every branch.

## Git conventions

- Branch names: `member-a` (the integrator's own editing branch),
  `member-b`, `member-c` (long-lived, one per teammate). The integrator
  switches to `main` only to merge verified work. Before writing files for the
  human, check which branch is checked out (`.git/HEAD`); the working folder
  always reflects the current branch.
- The repo is currently Public so that all three can use GitKraken's free
  tier (private remotes need a paid plan). Never put secrets, personal data,
  or student IDs in the repo.
- Commit messages in English: `[area] what changed`, for example
  `[cam] add capture state machine`. Areas: cam, vis, cnn, hdmi, srv, bt,
  ctrl, top, constr, ip, ml, scripts, docs.
- Milestone tags (integrator only): `proposal-v1`, `video-v1`, `demo-v1`,
  `report-v1`. Deadlines may move; add new tags instead of freezing `main`.
- `main` must always build. Before merging a branch into `main`, run
  `scripts/check.bat` (or `vivado -mode batch -source scripts/check.tcl`)
  and confirm `build/check_result.txt` says PASS.
- In a PR description state: what changed, whether it was synthesized, and
  whether it was tested on the board.

## Vivado working notes (learned the hard way)

- Project is created locally by `scripts/create_project.tcl`; sources are added
  by reference, so editing in Vivado edits the repo files directly. After a
  pull, re-run the script to pick up new or deleted files.
- Repo path must be ASCII-only and short (for example `D:/FPGA/FPGA-G6-FINAL`).
- In a Vivado MCP/Tcl session do not run `run all` on a testbench (it can
  hang the Tcl channel); use `run 2000ns`. A leftover `xsimk.exe` can block the
  next `launch_simulation`.
- When writing files through Tcl, a `$` can be dropped (`$finish` became
  `finish`). Re-read the written file and check every `$` system task.
- Program the board over USB-JTAG (PROG/UART port). The agent cannot see the
  physical LEDs; ask the human to report board behavior.

## Spec and deadlines

Course statements are in `docs/spec/`. Key dates: team registration 11/8,
proposal 11/15, intro video 12/7, exhibition 12/14, written report 12/21.
Material subsidy is limited (about NT$1,500 per group); do not suggest
purchases without the human confirming with the TA.

## When unsure

Ask the human. A wrong git action is expensive; a question is cheap.
