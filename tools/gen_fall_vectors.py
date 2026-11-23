"""Generate test vectors for sim/fall/tb_fall_detect.v from the Python model.

Run from the repo root:   python tools/gen_fall_vectors.py
Writes sim/fall/fall_vectors.mem. Each line is 14 hex digits:
    [55:52] posture_en   [51:48] expected fall flag
    [47:32] x   [31:16] y   [15:0] z   (16-bit two's complement)

The scenarios are synthetic (made up from simple shapes plus small noise).
They test that the Verilog and the Python model agree, and that the logic
does what it is meant to. They say nothing about real falls; that is what
the recorded trials are for.
"""
import os
import random

from fall_model import FallDetector, param_lut, MODE_ADULT

rng = random.Random(1)
G = 250


def noisy(x, y, z, n=4):
    return (x + rng.randint(-n, n), y + rng.randint(-n, n), z + rng.randint(-n, n))


def rest(samples, vec=(0, 0, G)):
    return [noisy(*vec) for _ in range(samples)]


def free_fall(samples):
    return [noisy(10, -8, 20) for _ in range(samples)]


def impact(samples=5, peak=900):
    return [noisy(peak // 2, -peak // 3, peak) for _ in range(samples)]


def shaking(samples):
    out = []
    for i in range(samples):
        s = 1 if (i // 3) % 2 else -1
        out.append(noisy(s * 300, s * 150, G + s * 200))
    return out


def scenarios():
    """Yield (name, posture_en, samples, expected number of falls)."""
    lying = (G, 0, 0)        # gravity moved from z to x: posture changed
    yield "rest only", 0, rest(400), 0
    yield "fall, lying still afterwards", 0, rest(300) + free_fall(30) + impact() + rest(450, lying), 1
    yield "fall, posture check on, posture changed", 1, rest(300) + free_fall(30) + impact() + rest(450, lying), 1
    yield "fall shape but posture unchanged, check on", 1, rest(300) + free_fall(30) + impact() + rest(450), 0
    yield "fall shape but posture unchanged, check off", 0, rest(300) + free_fall(30) + impact() + rest(450), 1
    yield "impact without free fall (bump)", 0, rest(300) + impact() + rest(450), 0
    yield "free fall without impact (arm drop)", 0, rest(300) + free_fall(30) + rest(450), 0
    yield "impact too late after free fall", 0, rest(300) + free_fall(30) + rest(120) + impact() + rest(450), 0
    yield "fall then keeps moving (got up, walking)", 0, rest(300) + free_fall(30) + impact() + shaking(450), 0
    yield "free fall too short", 0, rest(300) + free_fall(3) + impact() + rest(450), 0


def main():
    lft_sq, uft_sq, window = param_lut(MODE_ADULT, 170)
    lines, total_falls = [], 0
    det = FallDetector(lft_sq, uft_sq, window)
    for name, posture_en, samples, expected in scenarios():
        det.posture_en = bool(posture_en)
        falls = 0
        for x, y, z in samples + rest(150):          # gap so scenarios do not interact
            f = det.step(x, y, z)
            falls += f
            lines.append("%01X%01X%04X%04X%04X" % (posture_en, int(f), x & 0xFFFF, y & 0xFFFF, z & 0xFFFF))
        status = "ok" if falls == expected else "UNEXPECTED"
        print("%-48s falls=%d expected=%d %s" % (name, falls, expected, status))
        if falls != expected:
            raise SystemExit("model does not behave as intended in scenario: " + name)
        total_falls += falls

    out = os.path.join(os.path.dirname(__file__), "..", "sim", "fall", "fall_vectors.mem")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    print("wrote %d samples, %d falls -> %s" % (len(lines), total_falls, os.path.normpath(out)))
    print("thresholds: lft_sq=%d uft_sq=%d window=%d" % (lft_sq, uft_sq, window))


if __name__ == "__main__":
    main()
