# CLAUDE.md - rules for AI agents working in this repo

Read this file first. It is the machine-facing twin of README.md (written for
humans in Traditional Chinese). If the two ever disagree, stop and ask the
human.

## Project

- FPGA course final project, group 6, on a PYNQ-Z2 board (xc7z020clg400-1),
  Vivado 2019.2 on Windows. **The project topic has NOT been decided yet.**
  Do not invent one, and do not create code, folders, or constraints for a
  topic until the human says it is decided.
- Team of 3. The human maintainer is the **integrator**. Teammates are
  beginners with git and use a GUI (GitKraken or GitHub Desktop) plus a chat AI.
- History: an earlier "desktop pet" skeleton (Verilog, Vivado scripts, folder
  layout, AI rules) was removed on 2026-11-09 because the topic is undecided.
  It remains in git history if ever needed. Do not restore it unprompted.

## Repo map (current)

| Path | Content | Who edits |
|---|---|---|
| `README.md` | human-facing intro (Traditional Chinese) | integrator |
| `CLAUDE.md` | this file | integrator |
| `docs/manual/` | GitKraken manual for teammates | integrator |
| `docs/spec/` | course notices (English-named copies of the original txt files) | read-only reference |
| `.gitignore`, `.gitattributes` | ignore rules, line endings | integrator |

Once the topic is decided, the integrator will define the source layout,
naming rules, and subsystem owners here and in `README.md`.

## Hard rules (never violate)

1. Never force-push. Never `git reset --hard`, `git clean -fd`, or delete
   branches without the human explicitly asking in this session.
2. Never commit: `vivado_prj/`, `build/`, `*.bit`, `*.xpr`, videos, datasets,
   logs. `.gitignore` covers these; do not use `git add -f`.
3. Teammates push only to their own branch (`member-b`, `member-c`; names may
   change). Only the integrator merges into `main`.
4. On any merge conflict: stop, show the human the conflicting files, and wait.
5. The repo is **Public**. Never put secrets, tokens, personal data, or student
   IDs in it. Never ask for, print, or store GitHub tokens or passwords.
6. Do not use Vivado Block Design when code is added later; use plain
   Verilog and single-IP `.xci` files (to be confirmed when the topic is set).

## Git conventions

- Branches: `main` (integrator merges only), `member-a` (the integrator's own
  editing branch), `member-b`, `member-c` (teammates). Before writing files
  for the human, check which branch is checked out (`.git/HEAD`); the working
  folder always reflects the current branch.
- Commit messages in English: `[area] what changed`, for example
  `[docs] add meeting notes`. Area codes will be extended when the topic is set.
- Milestone tags (integrator only), when needed: `proposal-v1`, `video-v1`,
  `demo-v1`, `report-v1`. Deadlines may move; add new tags instead of freezing
  `main`.

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
