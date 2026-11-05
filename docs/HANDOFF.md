# HANDOFF.md - setup spec (historical record)

> **Status (2026-11-04): superseded.** The maintainer decided not to use
> Claude Code. Git steps are done by the maintainer in GitHub Desktop; the
> files in this repo were prepared by the Claude (Cowork) assistant, which
> cannot run git. Steps 1-2 below (spec move, subsystem folders) were already
> done before the first commit. This file is kept as a record of the setup
> design; the decisions in it still apply.

Audience: Claude Code running on the maintainer's Windows 11 PC (the
"integrator"). Goal: turn `D:\FPGA\FPGA-G6-FINAL` into a working private
GitHub repo that two teammates can clone. Read `CLAUDE.md` first.

The design was agreed in a long discussion with the maintainer. **Do not
change the decisions below.** If something looks wrong or impossible, stop and
ask the maintainer. Decisions that may still change: subsystem folder list,
branch names, tag names, owner table. Everything else is stable.

## Decisions (summary)

1. Private GitHub repo under the maintainer's personal account, name
   `FPGA-G6-FINAL` (confirm with the maintainer). Two collaborators.
2. Local path `D:\FPGA\FPGA-G6-FINAL` (ASCII only). The old Chinese-path
   folder is abandoned.
3. Vivado project is never committed. `scripts/create_project.tcl` rebuilds it
   locally; sources are added by reference. No Block Design; IP only as `.xci`.
4. Branches: maintainer on `main`; one long-lived branch per teammate
   (`member-b`, `member-c`); only the maintainer merges into `main`. No code
   freeze; milestone snapshots via tags.
5. Not in git: videos (Google Drive), `.bit` (GitHub Releases at milestones),
   `vivado_prj/`, datasets, large model files.
6. Teammates use GitHub Desktop (English UI) and may chat with an AI; they do
   not use agents. `scripts/sync.bat` and `scripts/save.bat` are backups that
   need Git for Windows.
7. Human-facing docs in Traditional Chinese (`README.md`, `docs/manual/`,
   folder READMEs); agent-facing docs in English (`CLAUDE.md`,
   `docs/AI_RULES.md`, this file).

## Files already prepared in this folder

`README.md`, `CLAUDE.md`, `.gitignore`, `.gitattributes`, `docs/*`,
`rtl/top/pet_top.v`, `rtl/ctrl/*.v`, `sim/ctrl/tb_ctrl_heartbeat.v`,
`constr/board_pynqz2.xdc`, `scripts/*`, and per-folder `README.md` files.
The spec text files are still in the old subfolder `題目與評分標準/`.

## Steps

Work through the steps in order. After each step report in one line what you
did. Ask before any destructive action.

### 0. Preconditions

- Run `git --version` and `gh --version`. If missing, propose
  `winget install --id Git.Git -e` and `winget install --id GitHub.cli -e`
  and wait for approval.
- Run `gh auth status`. If not logged in, tell the maintainer to run
  `gh auth login` himself (GitHub.com, HTTPS, browser). Never ask for tokens.
- Ask the maintainer for the git identity (`user.name`, `user.email`) and the
  GitHub username; do not guess. Set them with `git config` for this repo only.

### 1. Move the spec files

Create `docs/spec/` and move the four files from `題目與評分標準/`, renaming
them to ASCII names:

| Old name | New name |
|---|---|
| 期末專案.txt | final_project_overview.txt |
| 期末專案提案與採購清單.txt | proposal_and_procurement.txt |
| 期末專提書面報告.txt | final_report.txt |
| 期末專題展演影片.txt | demo_video.txt |

Use `Move-Item` (not delete). Afterwards the old folder must be empty; ask the
maintainer before removing it. Keep file contents unchanged.

### 2. Create the empty subsystem folders

For each of `camera vision cnn hdmi servo bluetooth` create `rtl/<name>/` and
`sim/<name>/`. In each `rtl/<name>/` create `README.md` from
`docs/templates/SUBSYSTEM_README.md` (replace the placeholder name; leave the
owner as "TBD"). `rtl/ctrl/` and `sim/ctrl/` already exist; give `rtl/ctrl/`
a README the same way (owner: integrator). Add an empty `.gitkeep` to each
`sim/<name>/` so git keeps the folder.

### 3. Verify the Vivado flow (must pass before any git commit)

Vivado 2019.2 is normally at `D:/Xilinx/Vivado/2019.2/bin/vivado.bat`.

a. Syntax-check the Verilog and testbench, then run the simulation of
   `tb_ctrl_heartbeat` for 2000 ns. Expected output contains `TB PASS`.
   (Use the Vivado MCP tools if available; otherwise `xvlog`/`xelab`/`xsim`
   from batch mode. Never use `run all`.)
b. Run `vivado -mode batch -source scripts/create_project.tcl` from a scratch
   copy or from the repo; confirm `vivado_prj/pet.xpr` is created and the log
   says `added rtl=3 ... top = pet_top`.
c. Run `scripts/create_project.tcl` a second time on the existing project and
   confirm it reports `added rtl=0 ip=0 xdc=0 sim=0 removed=0`. If it re-adds
   files, the path comparison in `add_missing` needs fixing; fix and re-test.
d. Run `scripts/check.bat` (or the batch command inside it). Expect
   `build/check_result.txt` to contain `PASS`.
e. Optional but recommended: ask the maintainer to program the board and
   confirm LED0 blinks about once per second, LED1 lights up, and holding
   BTN3 turns LED1 off.

These scripts were written without access to a running Vivado. Treat any
failure as a bug in the scripts: fix it, keep the behavior described in the
script headers, and tell the maintainer what you changed.

### 4. First commit and GitHub repo

```
git init -b main
git add -A
git status            # review: no vivado_prj/, build/, *.bit, videos
git commit -m "[top] initial repo skeleton"
gh repo create FPGA-G6-FINAL --private --source . --remote origin --push
```

Confirm with the maintainer that the visibility is private before pushing.

### 5. Branches and tags

```
git branch member-b && git branch member-c
git push -u origin member-b member-c
git tag setup-v1 && git push origin setup-v1
```

Branch names may change; ask the maintainer first.

### 6. Invite collaborators

Ask the maintainer for the two teammates' GitHub usernames and confirm them
back before acting. Then, for each:

```
gh api -X PUT repos/<owner>/FPGA-G6-FINAL/collaborators/<username> -f permission=push
```

### 7. Clone test

Clone the repo into a fresh ASCII path (for example
`D:\FPGA\_clone_test\FPGA-G6-FINAL`), run `scripts/create_project.tcl` and
`scripts/check.bat` there, and confirm both pass. This proves a teammate can
start from nothing. Ask before deleting the test folder.

### 8. Report to the maintainer

End with exactly three items:
1. What the maintainer must do now (for example: send the GitHub Desktop
   setup message to teammates; accept nothing is pending on his side).
2. What you just did (steps completed, commit hash, repo URL, tags).
3. What you plan to do next (for example: GitHub branch protection check,
   writing `docs/manual/` with screenshots after a real teammate walkthrough).

## Things not decided yet (do not invent)

- Who owns which subsystem (decided around the 11/15 proposal).
- Pet name and story; HDMI encoder source (to ask the TA); CNN toolchain.
- Whether GitHub branch protection is available on the maintainer's plan.
  Check the real GitHub documentation or UI; do not assume.
