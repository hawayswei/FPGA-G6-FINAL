"""Statistics for recorded fall / daily-activity trials.

Usage (from the repo root):
    python tools/analyze_trials.py data/trials
    python tools/analyze_trials.py data/trials --mode elderly --height 160 --posture
    python tools/analyze_trials.py data/demo_trials --no-plots

Input : a folder of CSV files, one trial per file, named
            <action>_<person>_<number>.csv      e.g. fall_front_A_01.csv
        Actions starting with "fall" count as falls, everything else as daily
        activity (should NOT trigger). Files come from scripts/capture.tcl
        (Vivado ILA export) or any CSV with x, y, z columns.
Output: <folder>/_report/
            trials.csv        one row per trial with all features
            summary.txt       per-action statistics, detection / false-alarm
                              rates, threshold sweep with a suggested setting
            plots/*.png       magnitude curve of every trial (needs matplotlib)
            scatter.png       min vs max magnitude of all trials

Only the Python standard library is required; matplotlib is optional.
1 g = 250 LSB, 100 samples per second (see tools/fall_model.py).
"""
import argparse
import csv
import math
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fall_model as fm  # noqa: E402

G = fm.G_LSB
HZ = fm.SAMPLE_HZ
MODES = {"adult": fm.MODE_ADULT, "elderly": fm.MODE_ELDERLY, "sport": fm.MODE_SPORT}


# ----------------------------------------------------------------------------
# Loading
# ----------------------------------------------------------------------------
def _to_signed16(text, radix):
    text = text.strip()
    if radix == "HEX":
        v = int(text, 16)
    elif radix == "BINARY":
        v = int(text, 2)
    else:
        v = int(float(text))
    if radix in ("HEX", "BINARY", "UNSIGNED") and v >= 0x8000:
        v -= 0x10000
    return v


def _find_axis_columns(header):
    cols = {}
    for axis in "xyz":
        for i, name in enumerate(header):
            n = name.strip().lower()
            if n == axis or ("accel_" + axis) in n or n.endswith("_" + axis):
                cols[axis] = i
                break
    return cols if len(cols) == 3 else None


def load_trial(path):
    """Return a list of (x, y, z) integers in LSB."""
    with open(path, newline="") as fh:
        rows = [r for r in csv.reader(fh) if r and any(c.strip() for c in r)]
    if len(rows) < 2:
        raise ValueError("file has no data")
    cols = _find_axis_columns(rows[0])
    if cols is None:
        raise ValueError("cannot find x / y / z columns in header: %s" % rows[0])
    first = 1
    radix = {a: "SIGNED" for a in "xyz"}
    if rows[1][0].strip().lower().startswith("radix"):      # Vivado ILA export
        first = 2
        for a in "xyz":
            cell = rows[1][cols[a]].upper()
            cell = cell.replace("RADIX", "").replace("-", "").strip()
            radix[a] = cell or "HEX"
    samples = []
    for r in rows[first:]:
        try:
            samples.append(tuple(_to_signed16(r[cols[a]], radix[a]) for a in "xyz"))
        except (ValueError, IndexError):
            continue                                         # skip broken lines
    if not samples:
        raise ValueError("no readable samples")
    return samples


def parse_name(path):
    """fall_front_A_01.csv -> (action 'fall_front', person 'A', number '01')."""
    stem = os.path.splitext(os.path.basename(path))[0]
    parts = stem.split("_")
    if len(parts) >= 3:
        return "_".join(parts[:-2]), parts[-2], parts[-1]
    return stem, "?", "?"


# ----------------------------------------------------------------------------
# Features
# ----------------------------------------------------------------------------
def _mean_vec(samples):
    n = max(len(samples), 1)
    return [sum(s[i] for s in samples) / n for i in range(3)]


def _angle_deg(a, b):
    na = math.sqrt(sum(v * v for v in a))
    nb = math.sqrt(sum(v * v for v in b))
    if na == 0 or nb == 0:
        return float("nan")
    c = max(-1.0, min(1.0, sum(x * y for x, y in zip(a, b)) / (na * nb)))
    return math.degrees(math.acos(c))


def features(samples, low_g=0.5):
    mag = [math.sqrt(x * x + y * y + z * z) / G for x, y, z in samples]
    i_max = max(range(len(mag)), key=mag.__getitem__)
    # lowest point in the second before the peak = free-fall phase
    lo_start = max(0, i_max - HZ)
    i_min = min(range(lo_start, i_max + 1), key=mag.__getitem__)
    # longest run below low_g before the peak
    run = best = 0
    for v in mag[lo_start:i_max + 1]:
        run = run + 1 if v < low_g else 0
        best = max(best, run)
    # stillness 1 s .. 3 s after the peak
    post = mag[i_max + HZ:i_max + 3 * HZ]
    post_std = statistics.pstdev(post) if len(post) > 1 else float("nan")
    post_bad = (sum(1 for v in post if v < 0.8 or v > 1.2) / len(post)) if post else float("nan")
    # posture: gravity direction 2..1 s before the low point vs 1..3 s after the peak
    pre_vec = _mean_vec(samples[max(0, i_min - 2 * HZ):max(1, i_min - HZ)])
    post_vec = _mean_vec(samples[i_max + HZ:i_max + 3 * HZ]) if post else [0, 0, 0]
    return {
        "samples": len(samples),
        "seconds": len(samples) / HZ,
        "min_g": mag[i_min],
        "max_g": mag[i_max],
        "t_min_to_max_s": (i_max - i_min) / HZ,
        "freefall_ms": best * 1000 // HZ,
        "post_std_g": post_std,
        "post_moving_frac": post_bad,
        "posture_change_deg": _angle_deg(pre_vec, post_vec),
        "_mag": mag, "_i_min": i_min, "_i_max": i_max,
    }


# ----------------------------------------------------------------------------
# Report
# ----------------------------------------------------------------------------
def fmt(v, digits=2):
    if isinstance(v, float):
        return "nan" if math.isnan(v) else ("%." + str(digits) + "f") % v
    return str(v)


def stats_line(values):
    vals = [v for v in values if not (isinstance(v, float) and math.isnan(v))]
    if not vals:
        return "n/a"
    return "mean %s  min %s  max %s" % (fmt(statistics.mean(vals)), fmt(min(vals)), fmt(max(vals)))


def rates(trials, detect):
    falls = [t for t in trials if t["is_fall"]]
    adls = [t for t in trials if not t["is_fall"]]
    hit = sum(1 for t in falls if detect(t))
    false = sum(1 for t in adls if detect(t))
    return hit, len(falls), false, len(adls)


def main():
    ap = argparse.ArgumentParser(description="Statistics for recorded fall trials")
    ap.add_argument("folder", help="folder with one CSV per trial")
    ap.add_argument("--mode", choices=sorted(MODES), default="adult")
    ap.add_argument("--height", type=int, default=170, help="user height in cm")
    ap.add_argument("--posture", action="store_true", help="also require a posture change")
    ap.add_argument("--no-plots", action="store_true")
    args = ap.parse_args()

    files = sorted(f for f in os.listdir(args.folder) if f.lower().endswith(".csv"))
    if not files:
        raise SystemExit("no .csv files in " + args.folder)
    out_dir = os.path.join(args.folder, "_report")
    os.makedirs(os.path.join(out_dir, "plots"), exist_ok=True)

    lft_sq, uft_sq, window = fm.param_lut(MODES[args.mode], args.height)
    trials, skipped = [], []
    for name in files:
        path = os.path.join(args.folder, name)
        try:
            samples = load_trial(path)
        except ValueError as exc:
            skipped.append("%s: %s" % (name, exc))
            continue
        action, person, number = parse_name(path)
        t = {"file": name, "action": action, "person": person, "number": number,
             "is_fall": action.lower().startswith("fall"), "_samples": samples}
        t.update(features(samples))
        hits = fm.run(samples, lft_sq=lft_sq, uft_sq=uft_sq, window=window, posture_en=args.posture)
        t["detected"] = int(bool(hits))
        t["detect_time_s"] = hits[0] / HZ if hits else float("nan")
        trials.append(t)
    if not trials:
        raise SystemExit("no readable trials. Problems:\n" + "\n".join(skipped))

    # ---- trials.csv ---------------------------------------------------------
    cols = ["file", "action", "person", "number", "is_fall", "detected", "detect_time_s",
            "seconds", "min_g", "max_g", "t_min_to_max_s", "freefall_ms",
            "post_std_g", "post_moving_frac", "posture_change_deg"]
    with open(os.path.join(out_dir, "trials.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(cols)
        for t in trials:
            w.writerow([fmt(t[c], 3) if isinstance(t[c], float) else t[c] for c in cols])

    # ---- summary.txt --------------------------------------------------------
    L = []
    L.append("Trials: %d (%d falls, %d daily activities)   folder: %s" % (
        len(trials), sum(t["is_fall"] for t in trials), sum(not t["is_fall"] for t in trials), args.folder))
    L.append("Detector settings: mode=%s height=%d cm posture check=%s" % (
        args.mode, args.height, "on" if args.posture else "off"))
    L.append("  free-fall threshold %.2f g, impact threshold %.2f g, window %d ms" % (
        math.sqrt(lft_sq) / G, math.sqrt(uft_sq) / G, window * 1000 // HZ))
    L.append("")
    L.append("== Per action ==")
    for action in sorted({t["action"] for t in trials}):
        ts = [t for t in trials if t["action"] == action]
        L.append("%s  (%d trials, detected %d)" % (action, len(ts), sum(t["detected"] for t in ts)))
        for key, label in (("min_g", "lowest |a| before peak (g)"), ("max_g", "peak |a| (g)"),
                           ("t_min_to_max_s", "lowest -> peak (s)"), ("freefall_ms", "free fall (ms)"),
                           ("post_moving_frac", "moving fraction after impact"),
                           ("posture_change_deg", "posture change (deg)")):
            L.append("    %-30s %s" % (label, stats_line([t[key] for t in ts])))
    L.append("")
    L.append("== Result with the settings above ==")
    hit, n_fall, false, n_adl = rates(trials, lambda t: t["detected"])
    if n_fall:
        L.append("Falls detected      : %d / %d = %.0f%%   (goal >= 90%%)" % (hit, n_fall, 100.0 * hit / n_fall))
    if n_adl:
        L.append("False alarms (daily): %d / %d = %.0f%%   (goal <= 5%% per action)" % (false, n_adl, 100.0 * false / n_adl))
    missed = [t["file"] for t in trials if t["is_fall"] and not t["detected"]]
    wrong = [t["file"] for t in trials if not t["is_fall"] and t["detected"]]
    if missed:
        L.append("Missed falls : " + ", ".join(missed))
    if wrong:
        L.append("False alarms : " + ", ".join(wrong))

    # ---- threshold sweep ------------------------------------------------------
    L.append("")
    L.append("== Threshold sweep (full detector re-run for every pair) ==")
    L.append("rows: impact threshold (g); columns: free-fall threshold (g)")
    L.append("cell: falls detected %% / false alarms %%")
    lfts = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
    ufts = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
    L.append("        " + "".join("%-11s" % ("%.1f g" % v) for v in lfts))
    best = None
    for u in ufts:
        cells = []
        for lo in lfts:
            def det(t, lo=lo, u=u):
                return bool(fm.run(t["_samples"], lft_sq=fm.g_to_sq(lo), uft_sq=fm.g_to_sq(u),
                                   window=window, posture_en=args.posture))
            hit, n_fall, false, n_adl = rates(trials, det)
            sens = 100.0 * hit / n_fall if n_fall else float("nan")
            fa = 100.0 * false / n_adl if n_adl else float("nan")
            cells.append("%-11s" % ("%s/%s" % (fmt(sens, 0), fmt(fa, 0))))
            score = (0 if math.isnan(sens) else sens) - (0 if math.isnan(fa) else fa)
            if best is None or score > best[0]:
                best = (score, lo, u, sens, fa)
        L.append("%-8s" % ("%.1f g" % u) + "".join(cells))
    L.append("")
    L.append("Suggested (highest detection minus false alarms): free-fall %.1f g, impact %.1f g "
             "-> detected %s%%, false alarms %s%%" % (best[1], best[2], fmt(best[3], 0), fmt(best[4], 0)))
    L.append("  squared values for rtl/fall/fall_param_lut.v: LFT = %d, UFT = %d" % (
        fm.g_to_sq(best[1]), fm.g_to_sq(best[2])))
    L.append("  Treat this as a starting point: with few trials several pairs tie.")
    if skipped:
        L.append("")
        L.append("== Skipped files ==")
        L.extend(skipped)
    text = "\n".join(L)
    with open(os.path.join(out_dir, "summary.txt"), "w", encoding="utf-8") as fh:
        fh.write(text + "\n")
    print(text)

    # ---- plots ---------------------------------------------------------------
    if not args.no_plots:
        try:
            import matplotlib
            matplotlib.use("Agg")
            import matplotlib.pyplot as plt
        except ImportError:
            print("\n(matplotlib not installed: skipped plots. Install with: pip install matplotlib)")
        else:
            for t in trials:
                tt = [i / HZ for i in range(len(t["_mag"]))]
                fig, ax = plt.subplots(2, 1, figsize=(9, 6), sharex=True)
                ax[0].plot(tt, t["_mag"], color="black", linewidth=1)
                ax[0].axhline(math.sqrt(lft_sq) / G, color="tab:blue", linestyle="--", label="free-fall threshold")
                ax[0].axhline(math.sqrt(uft_sq) / G, color="tab:red", linestyle="--", label="impact threshold")
                if not math.isnan(t["detect_time_s"]):
                    ax[0].axvline(t["detect_time_s"], color="tab:green", label="fall reported")
                ax[0].set_ylabel("|a| (g)")
                ax[0].set_title("%s   detected=%d" % (t["file"], t["detected"]))
                ax[0].legend(loc="upper right", fontsize=8)
                for i, (name, color) in enumerate((("x", "tab:red"), ("y", "tab:green"), ("z", "tab:blue"))):
                    ax[1].plot(tt, [s[i] / G for s in t["_samples"]], color=color, linewidth=1, label=name)
                ax[1].set_ylabel("axis (g)")
                ax[1].set_xlabel("time (s)")
                ax[1].legend(loc="upper right", fontsize=8)
                fig.tight_layout()
                fig.savefig(os.path.join(out_dir, "plots", os.path.splitext(t["file"])[0] + ".png"), dpi=110)
                plt.close(fig)
            fig, ax = plt.subplots(figsize=(7, 6))
            for is_fall, color, label in ((True, "tab:red", "fall"), (False, "tab:blue", "daily activity")):
                ts = [t for t in trials if t["is_fall"] == is_fall]
                ax.scatter([t["min_g"] for t in ts], [t["max_g"] for t in ts], color=color, label=label, alpha=0.7)
            ax.axvline(math.sqrt(lft_sq) / G, color="gray", linestyle="--")
            ax.axhline(math.sqrt(uft_sq) / G, color="gray", linestyle="--")
            ax.set_xlabel("lowest |a| before the peak (g)")
            ax.set_ylabel("peak |a| (g)")
            ax.set_title("Falls should sit in the upper-left corner")
            ax.legend()
            fig.tight_layout()
            fig.savefig(os.path.join(out_dir, "scatter.png"), dpi=110)
            plt.close(fig)
            print("\nplots written to " + os.path.join(out_dir, "plots"))
    print("report written to " + out_dir)


if __name__ == "__main__":
    main()
