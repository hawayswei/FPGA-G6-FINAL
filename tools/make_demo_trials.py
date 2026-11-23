"""Make FAKE trial files so the analysis tool can be tried without hardware.

Run from the repo root:   python tools/make_demo_trials.py
Writes data/demo_trials/*.csv in the same layout as a Vivado ILA export.

The data is synthetic (simple shapes plus noise). Never use it for the report
or to choose thresholds; it only shows how analyze_trials.py is used.
"""
import math
import os
import random

G = 250
rng = random.Random(7)


def n(v, s=6):
    return int(round(v + rng.gauss(0, s)))


def rest(k, vec):
    return [(n(vec[0]), n(vec[1]), n(vec[2])) for _ in range(k)]


def fall(direction):
    up = (0, 0, G)
    lying = {"front": (G, 0, 0), "back": (-G, 0, 0), "left": (0, G, 0), "right": (0, -G, 0)}[direction]
    out = rest(rng.randint(250, 350), up)
    out += [(n(15), n(10), n(rng.randint(10, 60))) for _ in range(rng.randint(25, 45))]      # free fall
    peak = rng.randint(650, 1100)
    out += [(n(lying[0] * peak / G * 0.8, 30), n(lying[1] * peak / G * 0.8, 30), n(peak * 0.5, 30))
            for _ in range(rng.randint(3, 6))]                                               # impact
    out += [(n(lying[0], 60), n(lying[1], 60), n(lying[2], 60)) for _ in range(40)]          # bounce
    out += rest(450, lying)
    return out


def walk():
    out = []
    for i in range(1000):
        s = math.sin(2 * math.pi * i / 55)
        out.append((n(40 * s, 10), n(25 * s, 10), n(G + 90 * s, 10)))
    return out


def sit():
    out = rest(300, (0, 0, G))
    out += [(n(20), n(10), n(G - 70 - i)) for i in range(25)]        # lowering
    out += [(n(60, 20), n(20, 20), n(G + 190, 20)) for _ in range(4)]  # seat contact
    out += rest(500, (40, 0, G - 5))
    return out


def stand():
    out = rest(300, (40, 0, G - 5))
    out += [(n(30), n(10), n(G + 60)) for _ in range(30)]
    out += [(n(10), n(5), n(G - 50)) for _ in range(25)]
    out += rest(500, (0, 0, G))
    return out


def write(path, samples):
    with open(path, "w", newline="\n") as fh:
        fh.write("Sample in Buffer,Sample in Window,TRIGGER,accel_valid,accel_x[15:0],accel_y[15:0],accel_z[15:0]\n")
        fh.write("Radix - UNSIGNED,UNSIGNED,UNSIGNED,UNSIGNED,HEX,HEX,HEX\n")
        for i, (x, y, z) in enumerate(samples):
            fh.write("%d,%d,%d,1,%04x,%04x,%04x\n" % (i, i, 1 if i == 0 else 0, x & 0xFFFF, y & 0xFFFF, z & 0xFFFF))


def main():
    out_dir = os.path.join(os.path.dirname(__file__), "..", "data", "demo_trials")
    os.makedirs(out_dir, exist_ok=True)
    count = 0
    for person in "AB":
        for k in range(1, 4):
            for d in ("front", "back", "left", "right"):
                write(os.path.join(out_dir, "fall_%s_%s_%02d.csv" % (d, person, k)), fall(d))
                count += 1
            for name, fn in (("adl_walk", walk), ("adl_sit", sit), ("adl_stand", stand)):
                write(os.path.join(out_dir, "%s_%s_%02d.csv" % (name, person, k)), fn())
                count += 1
    print("wrote %d fake trials to %s" % (count, os.path.normpath(out_dir)))


if __name__ == "__main__":
    main()
